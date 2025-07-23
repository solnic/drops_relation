defmodule Drops.Relation.Plugins.Schema do
  @moduledoc """
  Plugin that provides schema definition and automatic inference capabilities.

  This plugin adds the `schema/1` and `schema/2` macros for defining relation schemas.
  It supports both automatic schema inference from database tables and manual schema
  definition with Ecto.Schema syntax.

  ## Automatic Schema Inference

  The most common usage is to automatically infer the complete schema from the database:

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)  # Infers all fields, types, and relationships
      end

      # Access the inferred schema
      schema = MyApp.Users.schema()
      fields = schema.fields  # All database columns as Field structs

  ## Manual Schema Definition

  You can also define schemas manually using familiar Ecto.Schema syntax:

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users") do
          field(:name, :string)
          field(:email, :string)
          field(:active, :boolean, default: true)

          timestamps()
        end
      end

  ## Field Selection from Inferred Schema

  Select only specific fields from an automatically inferred schema:

      defmodule MyApp.UserSummary do
        use Drops.Relation, repo: MyApp.Repo

        schema([:id, :name, :email])  # Only include specific fields from inferred schema
      end

  ## Hybrid Approach

  Combine automatic inference with manual customizations:

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true) do
          # Add custom virtual fields
          field(:full_name, :string, virtual: true)

          # Add associations not inferred from foreign keys
          has_many(:posts, MyApp.Posts)
        end
      end

  ## Schema Access

  All relation modules provide access to their schema metadata:

      # Get the complete schema
      schema = MyApp.Users.schema()

      # Access specific fields
      email_field = schema[:email]

      # Get the generated Ecto schema module
      schema_module = MyApp.Users.__schema_module__()
      # => MyApp.Users.Struct

      # Create struct instances
      user = MyApp.Users.struct(%{name: "John", email: "john@example.com"})
      # => %MyApp.Users.Struct{name: "John", email: "john@example.com"}

  ## Options

  - `infer: true` - Automatically infer schema from database (default)
  - `struct: "CustomName"` - Use custom struct module name
  - Standard Ecto.Schema options are supported in manual definitions
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Cache
  alias Drops.Relation.Generator

  use Drops.Relation.Plugin, imports: [schema: 1, schema: 2]

  defmodule Macros.Schema do
    @moduledoc false

    use Drops.Relation.Plugin.MacroStruct,
      key: :schema,
      struct: [:name, block: nil, fields: nil, opts: [], infer: true]

    def new(name) when is_binary(name) do
      %Macros.Schema{name: name}
    end

    def new(fields, opts) when is_list(fields) do
      %Macros.Schema{name: nil, fields: fields, opts: opts}
    end

    def new(name, opts) when is_binary(name) and is_list(opts) do
      opts = Keyword.delete(opts, :do)
      infer = Keyword.get(opts, :infer, true)

      %{new(name) | opts: opts, infer: infer}
    end

    def new(name, opts, block) when is_binary(name) and is_list(opts) do
      %{new(name, opts) | block: block}
    end
  end

  defmacro schema(fields, opts \\ [])

  defmacro schema(name, opts) when is_binary(name) do
    block = opts[:do]

    quote do
      @context update_context(__MODULE__, Macros.Schema, [
                 unquote(name),
                 unquote(Keyword.delete(opts, :do)),
                 unquote(Macro.escape(block))
               ])
    end
  end

  defmacro schema(fields, opts) when is_list(fields) do
    quote do
      @context update_context(__MODULE__, Macros.Schema, [unquote(fields), unquote(opts)])
    end
  end

  def on(:before_compile, relation, %{opts: opts}) do
    put_schema(relation, opts)

    quote location: :keep do
      @spec schema() :: Schema.t()
      def schema, do: @schema
    end
  end

  def put_schema(relation, opts) do
    schema =
      case context(relation, :schema) do
        %{name: nil, fields: fields} when is_list(fields) ->
          Schema.project(opts[:source].schema(), fields)

        %{name: name, infer: true, block: block} ->
          source_schema =
            case infer_source_schema(relation, name, opts) do
              nil ->
                Schema.new(%{source: name})

              schema ->
                schema
            end

          if block do
            Schema.merge(source_schema, Generator.schema_from_block(name, block))
          else
            source_schema
          end
      end

    Module.put_attribute(relation, :schema, schema)
  end

  defp infer_source_schema(relation, name, opts) do
    repo = opts[:repo]
    file = Cache.get_cache_file_path(repo, name)

    Module.put_attribute(relation, :external_resource, file)

    Cache.get_cached_schema(repo, name)
  end
end
