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

      Module.register_attribute(__MODULE__, :schema, accumulate: false)
      Module.register_attribute(__MODULE__, :associations_block, accumulate: false)
      Module.register_attribute(__MODULE__, :views, accumulate: true)

      @before_compile Drops.Relation
      @after_compile Drops.Relation

      @opts unquote(opts)
      def opts, do: @opts

      defstruct([:struct, :repo, schema: %{}, queryable: [], opts: [], preloads: []])

      defmacro __using__(opts) do
        quote do
          import Drops.Relation

          Module.register_attribute(__MODULE__, :schema, accumulate: false)
          Module.register_attribute(__MODULE__, :associations_block, accumulate: false)
          Module.register_attribute(__MODULE__, :relation, accumulate: false)

          @before_compile Drops.Relation
          @after_compile Drops.Relation

          @opts unquote(opts)
          def opts, do: @opts

          @source unquote(opts[:source])
          def source, do: @source

          defstruct([
            :struct,
            :repo,
            schema: %{},
            queryable: unquote(opts[:source]),
            opts: [],
            preloads: []
          ])
        end
      end
    end
  end

  defmacro schema(fields) when is_list(fields) do
    quote do
      @schema unquote(fields)
    end
  end

  defmacro schema(table_name, opts \\ []) do
    quote do
      @schema unquote(Macro.escape({table_name, opts}))
    end
  end

  defmacro view(name, do: block) do
    quote do
      @views unquote(Macro.escape({name, block}))
    end
  end

  defmacro relation(do: block) do
    quote do
      @relation unquote(Macro.escape(block))
    end
  end

  defmacro __before_compile__(env) do
    relation = env.module
    opts = Module.get_attribute(relation, :opts)
    __define_relation__(env, opts)
  end

  defp view_module(relation, name) do
    Module.concat(relation, Macro.camelize(Atom.to_string(name)))
  end

  def __define_relation__(env, opts) do
    relation = env.module

    schema = Module.get_attribute(relation, :schema)
    relation_view = Module.get_attribute(relation, :relation, [])

    views = Module.get_attribute(relation, :views, [])
    view_mods = Enum.map(views, fn {name, _block} -> {name, view_module(relation, name)} end)

    view_ast =
      Enum.map(view_mods, fn {name, mod} ->
        mod_name = Atom.to_string(mod)

        quote do
          def unquote(name)(), do: String.to_existing_atom(unquote(mod_name)).queryable()
        end
      end)

    schema = __build_schema__(relation, schema, opts)

    queryable_ast =
      if relation_view do
        quote do
          def queryable, do: unquote(relation_view)
        end
      else
        quote do
          def queryable, do: unquote(relation)
        end
      end

    query_api_ast = Query.generate_functions(opts, schema) ++ view_ast

    singular_name =
      relation |> Atom.to_string() |> String.split(".") |> List.last() |> String.trim("s")

    ecto_schema_module = Module.concat([relation, "Schemas", singular_name])

    quote do
      @schema unquote(Macro.escape(schema))

      @spec schema() :: Drops.Relation.Schema.t()
      def schema, do: @schema

      unquote(queryable_ast)

      def new(opts \\ []) do
        new(queryable(), __schema_module__(), opts)
      end

      def new(queryable, struct, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          struct: struct,
          schema: Keyword.get(opts, :schema, schema()),
          repo: unquote(opts[:repo]),
          opts: opts,
          preloads: []
        })
      end

      # Make the relation module itself queryable by implementing the necessary functions
      # This allows the relation module to be used directly in Ecto queries
      def __schema__(query) do
        __schema_module__().__schema__(query)
      end

      def __schema__(query, field) do
        __schema_module__().__schema__(query, field)
      end

      @ecto_schema_module unquote(ecto_schema_module)
      def __schema_module__, do: @ecto_schema_module

      # Generate query API functions
      unquote_splicing(query_api_ast)

      # Handle when called with just options (e.g., users.restrict(name: "Jane"))
      def restrict(opts) when is_list(opts),
        do: __MODULE__.new(__schema_module__(), __schema_module__(), opts)

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
              __MODULE__.new(__schema_module__(), __schema_module__(), opts)

            association ->
              # Create a composite relation with automatic preloading
              right_relation = __MODULE__.new(__schema_module__(), __schema_module__(), opts)

              Drops.Relation.Composite.new(
                other_relation,
                right_relation,
                association,
                unquote(opts[:repo])
              )
          end
        else
          # Not a relation module, treat as regular queryable
          __MODULE__.new(other_relation, __schema_module__(), opts)
        end
      end

      def restrict(queryable, opts),
        do: __MODULE__.new(queryable, __schema_module__(), opts)

      # Helper function to check if a module is a relation module
      defp is_relation_module?(module) do
        function_exported?(module, :restrict, 2) and
          function_exported?(module, :ecto_schema, 1) and
          function_exported?(module, :associations, 0)
      end

      def ecto_schema(group), do: __schema_module__().__schema__(group)
      def ecto_schema(group, name), do: __schema_module__().__schema__(group, name)

      def association(name), do: __schema_module__().__schema__(:association, name)
      def associations(), do: __schema_module__().__schema__(:associations)

      def struct(attributes \\ %{}) do
        struct(__schema_module__(), attributes)
      end

      def preload(associations) when is_atom(associations) or is_list(associations) do
        preload(__MODULE__.new(__schema_module__(), __schema_module__(), []), associations)
      end

      def preload(%__MODULE__{} = relation, association) when is_atom(association) do
        preload(relation, [association])
      end

      def preload(%__MODULE__{} = relation, associations) when is_list(associations) do
        %{relation | preloads: relation.preloads ++ associations}
      end
    end
  end

  defmacro __after_compile__(env, _) do
    relation = env.module
    schema = Module.get_attribute(relation, :schema)

    if schema do
      __finalize_relation__(relation)
    else
      []
    end
  end

  def __build_schema__(relation, spec, opts) do
    case spec do
      {name, schema_opts} ->
        source_schema =
          if Keyword.get(schema_opts, :infer, true) do
            infer_source_schema(relation, name, opts)
          end

        block = schema_opts[:do]

        if is_nil(block) do
          source_schema
        else
          Module.put_attribute(relation, :schema_block, block)
          Schema.merge(source_schema, Generator.schema_from_block(name, block))
        end

      fields when is_list(fields) ->
        Schema.project(opts[:source].schema(), fields)
    end
  end

  def infer_source_schema(relation, name, opts) do
    repo = opts[:repo]
    cache_file = Drops.Relation.Cache.get_cache_file_path(repo, name)
    Module.put_attribute(relation, :external_resource, cache_file)
    Drops.Relation.Cache.get_cached_schema(repo, name)
  end

  def __finalize_relation__(relation) do
    opts = relation.opts()
    repo = opts[:repo]

    schema_block = Module.get_attribute(relation, :schema_block, [])
    ecto_schema = Generator.generate_module_content(relation.schema(), schema_block)

    Module.create(relation.__schema_module__(), ecto_schema, Macro.Env.location(__ENV__))

    views = Module.get_attribute(relation, :views, [])

    Enum.each(views, fn {name, block} ->
      {:module, _view_module, _, _} =
        Module.create(
          view_module(relation, name),
          quote do
            use unquote(relation),
              name: unquote(name),
              source: unquote(relation),
              repo: unquote(repo),
              view: true

            unquote(block)
          end,
          Macro.Env.location(__ENV__)
        )
    end)

    quote location: :keep do
      defimpl Enumerable, for: unquote(relation) do
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
          unquote(relation).all(relation)
        end
      end

      defimpl Ecto.Queryable, for: unquote(relation) do
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
end
