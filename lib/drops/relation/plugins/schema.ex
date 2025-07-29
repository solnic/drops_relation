defmodule Drops.Relation.Plugins.Schema do
  @moduledoc """
  Plugin that provides schema definition and automatic inference capabilities.

  This plugin adds the `schema/1` and `schema/2` macros for defining relation schemas.
  It supports both automatic schema inference from database tables and manual schema
  definition with Ecto.Schema syntax.
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.Field
  alias Drops.Relation.Cache
  alias Drops.Relation.Generator

  use Drops.Relation.Plugin, imports: [schema: 1, schema: 2, schema: 3]

  defmodule Macros.Schema do
    @moduledoc false

    use Drops.Relation.Plugin.MacroStruct,
      key: :schema,
      struct: [:name, block: nil, fields: nil, opts: [], infer: false]

    def new(name) when is_binary(name) do
      %Macros.Schema{name: name}
    end

    def new(fields, opts) when is_list(fields) do
      %Macros.Schema{name: nil, fields: fields, opts: opts}
    end

    def new(name, opts) when is_binary(name) and is_list(opts) do
      opts = Keyword.delete(opts, :do)
      infer = Keyword.get(opts, :infer, false)

      %{new(name) | opts: opts, infer: infer}
    end

    def new(name, opts, block) when is_binary(name) and is_list(opts) do
      %{new(name, opts) | block: block}
    end
  end

  @doc """
  Defines a schema for the relation.

  By default, this creates an empty schema that you must populate with manual field
  definitions. Use `infer: true` option to automatically introspect the database table.

  ## Parameters

  - `table_name` - String name of the database table
  - `opts` - Keyword list of options (optional)

  ## Options

  - `infer: false` - Use only manual field definitions (default: false)
  - `infer: true` - Automatically infer schema from database table
  - `struct: "CustomName"` - Use custom struct module name instead of default

  ## Returns

  Sets up the relation to generate:
  - A `schema/0` function that returns the complete schema metadata
  - A `schema/1` function that returns a specific field by name

  ## Examples

  Manual schema definition:

      iex> defmodule Relations.Users do
      ...>   use Drops.Relation, repo: MyApp.Repo
      ...>
      ...>   schema("users") do
      ...>     field(:name, :string)
      ...>     field(:email, :string)
      ...>   end
      ...> end
      ...>
      iex> user = Relations.Users.struct(%{name: "Alice Johnson", email: "alice@company.com"})
      iex> user.__struct__
      Relations.Users.User
      iex> user.name
      "Alice Johnson"
      iex> user.email
      "alice@company.com"

  With automatic inference:

      iex> defmodule Relations.Users do
      ...>   use Drops.Relation, repo: MyApp.Repo
      ...>
      ...>   schema("users", infer: true)
      ...> end
      iex> schema = Relations.Users.schema()
      iex> schema.source
      :users
      iex> length(schema.fields) > 0
      true

  With custom struct name:

      iex> defmodule Relations.People do
      ...>   use Drops.Relation, repo: MyApp.Repo
      ...>
      ...>   schema("users", struct: "Person", infer: true)
      ...> end
      ...>
      iex> user = Relations.People.struct(%{name: "Alice Johnson", email: "alice@company.com"})
      iex> user.__struct__
      Relations.People.Person
      iex> user.name
      "Alice Johnson"
      iex> user.email
      "alice@company.com"
  """
  defmacro schema(name, opts \\ [])

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

  @doc """
  Defines a schema with manual field definitions or combines inference with custom fields.

  This form allows you to either define a completely manual schema using Ecto.Schema
  syntax, or combine automatic inference with additional custom fields and associations.

  ## Parameters

  - `table_name` - String name of the database table
  - `opts` - Keyword list of options
  - `block` - Schema definition block using Ecto.Schema syntax

  ## Options

  - `infer: false` - Use only the manual field definitions in the block (default: false)
  - `infer: true` - Automatically infer schema from database and merge with block
  - `struct: "CustomName"` - Use custom struct module name

  ## Returns

  Sets up the relation with either a purely manual schema or a merged schema
  combining inference with custom definitions.

  ## Examples

      iex> defmodule Relations.Users do
      ...>   use Drops.Relation, repo: MyApp.Repo
      ...>
      ...>   schema("users", infer: true) do
      ...>     field(:role, :string, default: "member")
      ...>     field(:full_name, :string, virtual: true)
      ...>   end
      ...> end
      ...>
      iex> schema = Relations.Users.schema()
      iex> %{name: name, meta: %{default: default}} = schema[:role]
      iex> name
      :role
      iex> default
      "member"
  """
  defmacro schema(name, opts, block) when is_binary(name) do
    block = block[:do]

    quote do
      @context update_context(__MODULE__, Macros.Schema, [
                 unquote(name),
                 unquote(Keyword.delete(opts, :do)),
                 unquote(Macro.escape(block))
               ])
    end
  end

  def on(:before_compile, relation, %{opts: opts}) do
    put_schema(relation, opts)

    quote location: :keep do
      @spec schema() :: Schema.t()
      def schema, do: @schema

      @spec schema(atom()) :: Field.t() | nil
      def schema(name), do: @schema[name]
    end
  end

  @doc false
  def put_schema(relation, opts) do
    schema =
      case context(relation, :schema) do
        %{name: nil, fields: fields} when is_list(fields) ->
          Schema.project(opts[:source].schema(), fields)

        %{name: name, infer: true, block: block} ->
          source_schema =
            case infer_source_schema(relation, name, opts) do
              nil ->
                Schema.new(%{source: String.to_atom(name)})

              schema ->
                schema
            end

          if block do
            Schema.merge(source_schema, Generator.schema_from_block(name, block))
          else
            source_schema
          end

        %{name: name, infer: false, block: block} when not is_nil(block) ->
          Generator.schema_from_block(name, block)

        %{name: name, infer: false, block: nil} ->
          Schema.new(%{source: String.to_atom(name)})

        %{name: name, block: nil} ->
          Schema.new(%{source: String.to_atom(name)})
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
