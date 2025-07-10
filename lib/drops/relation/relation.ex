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

  alias Drops.Relation.Query
  alias Drops.Relation.Compilers.CodeCompiler

  defmacro __using__(opts) do
    quote do
      import Drops.Relation

      Module.register_attribute(__MODULE__, :custom_schema_definitions, accumulate: true)

      @before_compile Drops.Relation
      @after_compile Drops.Relation

      @opts unquote(opts)

      defstruct([:struct, :repo, queryable: [], opts: [], preloads: []])
    end
  end

  defmacro associations(do: block) do
    quote do
      @associations unquote(Macro.escape(block))
    end
  end

  defmacro schema(table_name, do: block) do
    quote do
      @custom_schema_definitions unquote(Macro.escape({table_name, block}))
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
      %Drops.Relation.Schema{} = drops_relation_schema ->
        __define_relation__(env, drops_relation_schema)

      {:error, error} ->
        raise error
        []

      nil ->
        []
    end
  end

  def __define_relation__(env, drops_relation_schema) do
    relation = env.module

    opts = Module.get_attribute(relation, :opts)
    repo = opts[:repo]
    name = opts[:name]

    association_definitions = Module.get_attribute(relation, :associations, [])
    custom_schema_definitions = Module.get_attribute(relation, :custom_schema_definitions, [])

    # Generate Ecto schema AST
    ecto_schema_ast =
      if custom_schema_definitions != [] do
        # Use the temporary Ecto schema modules approach to merge schemas
        final_schema =
          generate_merged_schema_from_temporary_modules(
            drops_relation_schema,
            custom_schema_definitions,
            association_definitions,
            name,
            relation
          )

        # Generate schema AST from the merged Drops.Relation.Schema
        generate_inferred_schema_ast(final_schema, association_definitions, name)
      else
        # Generate from inferred schema
        generate_inferred_schema_ast(drops_relation_schema, association_definitions, name)
      end

    # Generate the nested Schema module
    schema_module_ast = generate_schema_module(relation, ecto_schema_ast)

    # Generate query API functions
    query_api_ast = generate_query_api(opts, drops_relation_schema)

    quote location: :keep do
      require unquote(repo)

      # Define the nested Schema module
      unquote(schema_module_ast)

      # Store configuration as module attributes
      @opts unquote(Macro.escape(opts))
      @schema unquote(Macro.escape(drops_relation_schema))

      def new(queryable, struct, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          struct: struct,
          repo: unquote(repo),
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
                unquote(repo)
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
        try do
          function_exported?(module, :restrict, 2) and
            function_exported?(module, :ecto_schema, 1) and
            function_exported?(module, :associations, 0)
        rescue
          _ -> false
        end
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

    # Generate the module AST
    quote do
      defmodule unquote(struct_module_name) do
        use Ecto.Schema
        import Ecto.Schema
        unquote(ecto_schema_ast)
      end
    end
  end

  # Generates query API functions that delegate to module-level functions
  defp generate_query_api(opts, drops_relation_schema) do
    Query.generate_functions(opts, drops_relation_schema)
  end

  # Generate Ecto schema AST from inferred schema using CodeCompiler
  defp generate_inferred_schema_ast(schema, association_definitions, table_name) do
    # Use the new CodeCompiler to generate field definitions and attributes
    compiled_asts = CodeCompiler.visit(schema, [])

    # Separate attributes from field definitions
    {attributes, field_definitions} =
      Enum.split_with(compiled_asts, fn ast ->
        case ast do
          {:@, _, _} -> true
          _ -> false
        end
      end)

    # Add timestamps if we have both inserted_at and updated_at
    has_inserted_at = Enum.any?(schema.fields, &(&1.name == :inserted_at))
    has_updated_at = Enum.any?(schema.fields, &(&1.name == :updated_at))

    all_field_definitions =
      if has_inserted_at and has_updated_at do
        field_definitions ++ [quote(do: timestamps())]
      else
        field_definitions
      end

    # Create the schema AST
    schema_ast =
      quote location: :keep do
        Ecto.Schema.schema unquote(table_name) do
          (unquote_splicing(all_field_definitions))
          unquote(association_definitions)
        end
      end

    # Add attributes if needed
    if attributes != [] do
      quote location: :keep do
        (unquote_splicing(attributes))
        unquote(schema_ast)
      end
    else
      schema_ast
    end
  end

  # Generate merged schema from temporary Ecto schema modules
  defp generate_merged_schema_from_temporary_modules(
         inferred_schema,
         custom_schema_definitions,
         association_definitions,
         table_name,
         relation_module
       ) do
    # Generate temporary module name for inferred schema only
    inferred_module_name = Module.concat(relation_module, TempInferredSchema)

    # Generate the inferred Ecto schema module AST
    inferred_ecto_schema_ast =
      generate_inferred_schema_ast(inferred_schema, association_definitions, table_name)

    # Define temporary module for inferred schema
    define_temporary_schema_module(inferred_module_name, inferred_ecto_schema_ast)

    # Convert inferred module to Drops.Relation.Schema struct
    inferred_drops_schema = Drops.Relation.Compilers.EctoCompiler.visit(inferred_module_name, [])

    # Extract custom fields directly from AST to preserve original types
    custom_drops_schema = extract_custom_schema_from_ast(custom_schema_definitions, table_name)

    # Merge the schemas (custom takes precedence)
    merged_schema = Drops.Relation.Schema.merge(inferred_drops_schema, custom_drops_schema)

    # Clean up temporary module
    :code.purge(inferred_module_name)
    :code.delete(inferred_module_name)

    merged_schema
  end

  # Extract custom schema information directly from AST to preserve original types
  defp extract_custom_schema_from_ast([{table_name, schema_block}], _table_name_string) do
    # Extract field definitions from the schema block
    field_definitions = extract_field_definitions_from_block(schema_block)

    # Convert field definitions to Field structs
    custom_fields = Enum.map(field_definitions, &ast_to_field/1)

    # Create a minimal schema with just the custom fields
    # We don't need primary key, foreign keys, or indices from custom schema
    alias Drops.Relation.Schema

    Schema.new(
      Atom.to_string(table_name),
      # no primary key from custom schema
      nil,
      # no foreign keys from custom schema
      [],
      custom_fields,
      # no indices from custom schema
      []
    )
  end

  # Extract field definitions from schema block AST
  defp extract_field_definitions_from_block(schema_block) do
    case schema_block do
      {:__block__, _meta, field_definitions} ->
        Enum.filter(field_definitions, &is_field_definition?/1)

      single_definition when is_tuple(single_definition) ->
        if is_field_definition?(single_definition), do: [single_definition], else: []

      _ ->
        []
    end
  end

  # Check if an AST node is a field definition
  defp is_field_definition?({:field, _meta, _args}), do: true
  defp is_field_definition?(_), do: false

  # Convert field definition AST to Field struct
  defp ast_to_field({:field, _meta, [field_name, field_type]}) do
    alias Drops.Relation.Schema.Field
    # Evaluate the type AST to resolve aliases like Ecto.Enum
    resolved_type = resolve_type_ast(field_type)
    Field.new(field_name, resolved_type, %{source: field_name})
  end

  defp ast_to_field({:field, _meta, [field_name, field_type, opts]}) do
    alias Drops.Relation.Schema.Field

    # Evaluate the type AST to resolve aliases like Ecto.Enum
    resolved_type = resolve_type_ast(field_type)

    # Evaluate the options AST to resolve any complex values
    resolved_opts = resolve_opts_ast(opts)

    # For parameterized types, separate type options from field metadata
    {final_type, field_meta_opts} = separate_type_and_field_options(resolved_type, resolved_opts)

    # Extract metadata from field options (not type options)
    meta = %{
      source: Keyword.get(field_meta_opts, :source, field_name),
      default: Keyword.get(field_meta_opts, :default),
      nullable: Keyword.get(field_meta_opts, :null)
    }

    Field.new(field_name, final_type, meta)
  end

  # Separate type options from field metadata options
  defp separate_type_and_field_options(type, opts) do
    # Check if this is a parameterized type that needs options
    case type do
      Ecto.Enum ->
        # For Ecto.Enum, the 'values' option belongs to the type
        type_opts = Keyword.take(opts, [:values])
        field_opts = Keyword.drop(opts, [:values])
        final_type = if type_opts != [], do: {type, type_opts}, else: type
        {final_type, field_opts}

      # Add other parameterized types here as needed
      _ ->
        # For regular types, all options are field metadata
        {type, opts}
    end
  end

  # Resolve type AST to actual types
  defp resolve_type_ast(type_ast) do
    case type_ast do
      # Handle module aliases like Ecto.Enum
      {:__aliases__, _meta, module_parts} ->
        Module.concat(module_parts)

      # Handle tuples like {Ecto.Enum, opts}
      {type_ast, opts_ast} ->
        resolved_type = resolve_type_ast(type_ast)
        resolved_opts = resolve_opts_ast(opts_ast)
        {resolved_type, resolved_opts}

      # Handle atoms and other simple types
      atom when is_atom(atom) ->
        atom

      # Return as-is for other cases
      other ->
        other
    end
  end

  # Resolve options AST to actual values
  defp resolve_opts_ast(opts_ast) do
    case opts_ast do
      # Handle keyword lists
      list when is_list(list) ->
        Enum.map(list, fn
          {key, value_ast} -> {key, resolve_value_ast(value_ast)}
          other -> other
        end)

      # Return as-is for other cases
      other ->
        other
    end
  end

  # Resolve value AST to actual values
  defp resolve_value_ast(value_ast) do
    case value_ast do
      # Handle lists like [:red, :green, :blue]
      list when is_list(list) ->
        Enum.map(list, &resolve_value_ast/1)

      # Handle atoms, strings, numbers
      atom when is_atom(atom) ->
        atom

      string when is_binary(string) ->
        string

      number when is_number(number) ->
        number

      # Return as-is for other cases
      other ->
        other
    end
  end

  # Define a temporary Ecto schema module
  defp define_temporary_schema_module(module_name, schema_ast) do
    module_ast =
      quote do
        defmodule unquote(module_name) do
          use Ecto.Schema
          import Ecto.Schema
          unquote(schema_ast)
        end
      end

    # Compile the module
    Code.eval_quoted(module_ast)
  end
end
