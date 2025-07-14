defmodule Drops.Relation do
  @moduledoc """
  Provides a convenient query API that wraps Ecto.Schema and delegates to Ecto.Repo functions.

  This module generates relation modules that automatically infer database schemas and provide
  a query API that delegates to the configured Ecto repository. All functions accept an optional
  `:repo` option that overrides the default repository configured via the `use` macro.

  ## Usage

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo, name: "users"
      end

      # Query functions automatically use the configured repo
      user = MyApp.Users.get(1)
      users = MyApp.Users.all()

  ## Query API

  All query functions delegate to the corresponding `Ecto.Repo` functions. See the
  [Ecto.Repo documentation](https://hexdocs.pm/ecto/Ecto.Repo.html) for detailed information
  about each function's behavior and options.

  The `:repo` option is automatically passed based on the repository configured in the `use` macro,
  but can be overridden by passing a `:repo` option to any function call.
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Query
  alias Drops.Relation.Generator

  defmacro __using__(opts) do
    quote do
      import Drops.Relation

      Module.register_attribute(__MODULE__, :custom_schema_block, accumulate: true)

      @before_compile Drops.Relation
      @after_compile Drops.Relation

      @opts unquote(opts)

      defstruct([:struct, :repo, queryable: [], opts: [], preloads: []])
    end
  end

  defmacro schema(table_name, do: block) do
    quote do
      @custom_schema_block unquote(Macro.escape({table_name, block}))
    end
  end

  defmacro __before_compile__(env) do
    relation = env.module

    opts = Module.get_attribute(relation, :opts)
    repo = opts[:repo]
    name = opts[:name]

    # Register cache file as external resource for recompilation tracking
    cache_file = Drops.Relation.Cache.get_cache_file_path(repo, name)
    Module.put_attribute(relation, :external_resource, cache_file)

    case Drops.Relation.Cache.get_cached_schema(repo, name) do
      %Drops.Relation.Schema{} = inferred_schema ->
        __define_relation__(env, inferred_schema)

      {:error, error} ->
        raise error
        []

      nil ->
        []
    end
  end

  def __define_relation__(env, inferred_schema) do
    relation = env.module

    opts = Module.get_attribute(relation, :opts)
    custom_schema_block = Module.get_attribute(relation, :custom_schema_block, [])

    # Merge customized schema that was defined via regular `schema(name) do ... end` block
    # with the inferred schema, so that it's possible to override default fields settings.
    final_schema =
      if custom_schema_block != [] do
        custom_schema = Generator.schema_from_block(custom_schema_block)
        Schema.merge(inferred_schema, custom_schema)
      else
        inferred_schema
      end

    # Generate Ecto schema AST
    ecto_schema_ast = Generator.generate_schema_ast_from_schema(final_schema)

    # Generate the nested Schema module
    schema_module_ast = generate_schema_module(relation, ecto_schema_ast)

    # Generate query API functions
    query_api_ast = generate_query_api(opts, final_schema)

    quote location: :keep do
      # Define the nested Schema module
      unquote(schema_module_ast)

      # Store configuration as module attributes
      @opts unquote(Macro.escape(opts))
      @schema unquote(Macro.escape(final_schema))

      def new(queryable, struct, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          struct: struct,
          repo: unquote(opts[:repo]),
          opts: opts,
          preloads: []
        })
      end

      # Make the relation module itself queryable by implementing the necessary functions
      # This allows the relation module to be used directly in Ecto queries
      def __schema__(query) do
        Module.concat(__MODULE__, Struct).__schema__(query)
      end

      def __schema__(query, field) do
        Module.concat(__MODULE__, Struct).__schema__(query, field)
      end

      # Generate query API functions
      unquote_splicing(query_api_ast)

      @spec schema() :: Drops.Relation.Schema.t()
      def schema do
        @schema
      end

      # Handle when called with just options (e.g., users.restrict(name: "Jane"))
      def restrict(opts) when is_list(opts),
        do: __MODULE__.new(__MODULE__.Struct, __MODULE__.Struct, opts)

      def restrict(%__MODULE__{} = relation, opts) do
        # Preserve existing preloads when restricting a relation
        %{relation | opts: Keyword.merge(relation.opts, opts)}
      end

      # Handle composition between different relation types
      def restrict(%other_module{} = other_relation, opts)
          when other_module != __MODULE__ do
        # Check if this is a different relation module
        if is_relation_module?(other_module) do
          # Try to infer association between the relations
          case Drops.Relation.Composite.infer_association(other_module, __MODULE__) do
            nil ->
              # No association found, just create a regular restricted relation
              __MODULE__.new(__MODULE__.Struct, __MODULE__.Struct, opts)

            association ->
              # Create a composite relation with automatic preloading
              right_relation = __MODULE__.new(__MODULE__.Struct, __MODULE__.Struct, opts)

              Drops.Relation.Composite.new(
                other_relation,
                right_relation,
                association,
                unquote(opts[:repo])
              )
          end
        else
          # Not a relation module, treat as regular queryable
          __MODULE__.new(other_relation, __MODULE__.Struct, opts)
        end
      end

      def restrict(queryable, opts),
        do: __MODULE__.new(queryable, __MODULE__.Struct, opts)

      # Helper function to check if a module is a relation module
      defp is_relation_module?(module) do
        function_exported?(module, :restrict, 2) and
          function_exported?(module, :ecto_schema, 1) and
          function_exported?(module, :associations, 0)
      end

      def ecto_schema(group), do: __MODULE__.Struct.__schema__(group)
      def ecto_schema(group, name), do: __MODULE__.Struct.__schema__(group, name)

      def association(name), do: __MODULE__.Struct.__schema__(:association, name)
      def associations(), do: __MODULE__.Struct.__schema__(:associations)

      def struct(attributes \\ %{}) do
        struct(__MODULE__.Struct, attributes)
      end

      @doc """
      Preloads associations for the relation.

      This function creates a new relation with the specified associations marked for preloading.
      When the relation is enumerated or converted to a query, the associations will be preloaded.

      ## Parameters

      - `associations` - An atom, list of atoms, or keyword list specifying which associations to preload

      ## Examples

          # Preload a single association
          users.preload(:posts)

          # Preload multiple associations
          users.preload([:posts, :comments])

          # Preload with nested associations
          users.preload(posts: [:comments])

      ## Returns

      A new relation struct with the preload configuration applied.
      """
      def preload(associations) when is_atom(associations) or is_list(associations) do
        preload(__MODULE__.new(__MODULE__.Struct, __MODULE__.Struct, []), associations)
      end

      def preload(%__MODULE__{} = relation, associations)
          when is_atom(associations) or is_list(associations) do
        # Normalize associations to a list
        normalized_associations =
          case associations do
            atom when is_atom(atom) -> [atom]
            list when is_list(list) -> list
          end

        # Merge with existing preloads
        updated_preloads = relation.preloads ++ normalized_associations

        %{relation | preloads: updated_preloads}
      end
    end
  end

  defmacro __after_compile__(env, _) do
    module = env.module

    quote location: :keep do
      defimpl Enumerable, for: unquote(module) do
        import Ecto.Query

        def count(relation) do
          {:ok, length(materialize(relation))}
        end

        def member?(relation, value) do
          case materialize(relation) do
            {:ok, list} -> {:ok, value in list}
            {:error, _} = error -> error
          end
        end

        def slice(relation) do
          list = materialize(relation)
          size = length(list)

          {:ok, size, fn start, count, _step -> Enum.slice(list, start, count) end}
        end

        def reduce(relation, acc, fun) do
          Enumerable.List.reduce(materialize(relation), acc, fun)
        end

        defp materialize(relation) do
          unquote(module).all(relation)
        end
      end

      defimpl Ecto.Queryable, for: unquote(env.module) do
        import Ecto.Query

        def to_query(relation) do
          base_query = Ecto.Queryable.to_query(relation.struct)

          # Apply restrictions from opts
          query_with_restrictions =
            build_query_with_restrictions(base_query, relation.opts)

          # Apply preloads if any
          apply_preloads(query_with_restrictions, relation.preloads)
        end

        # Builds an Ecto query with WHERE clauses based on the restriction options
        defp build_query_with_restrictions(queryable, []) do
          queryable
        end

        defp build_query_with_restrictions(queryable, opts) do
          Enum.reduce(opts, queryable, fn {field, value}, query ->
            where(query, [r], field(r, ^field) == ^value)
          end)
        end

        # Applies preloads to the query
        defp apply_preloads(queryable, []) do
          queryable
        end

        defp apply_preloads(queryable, preloads) do
          from(q in queryable, preload: ^preloads)
        end
      end
    end
  end

  # Generates the Struct module as a separate, standalone module
  defp generate_schema_module(relation, ecto_schema_ast) do
    struct_module_name = Module.concat(relation, Struct)
    Generator.schema_module(struct_module_name, ecto_schema_ast)
  end

  # Generates query API functions that delegate to module-level functions
  defp generate_query_api(opts, drops_relation_schema) do
    Query.generate_functions(opts, drops_relation_schema)
  end
end
