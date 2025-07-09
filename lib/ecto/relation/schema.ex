defmodule Ecto.Relation.Schema do
  @moduledoc """
  Represents comprehensive schema metadata for a database table/relation.

  This struct stores all extracted metadata about a database table including
  primary keys, foreign keys, field information, and indices. It serves as
  a central container for schema information that can be used for validation,
  documentation, and code generation.

  ## Examples

      # Create a schema with metadata
      schema = %Ecto.Relation.Schema{
        source: "users",
        primary_key: %Ecto.Relation.Schema.PrimaryKey{fields: [:id]},
        foreign_keys: [],
        fields: [
          %{name: :id, type: :integer, ecto_type: :id, source: :id},
          %{name: :email, type: :string, ecto_type: :string, source: :email}
        ],
        indices: %Ecto.Relation.Schema.Indices{indices: [...]},
        associations: [
          # Ecto association structs (BelongsTo, Has, ManyToMany, etc.)
        ]
      }
  """

  defprotocol Inference do
    @spec to_schema(term()) :: Ecto.Relation.Schema.t()
    def to_schema(table)
  end

  alias Ecto.Relation.Schema.{PrimaryKey, ForeignKey, Indices, Field}

  @type field_metadata :: %{
          name: atom(),
          type: atom(),
          ecto_type: term(),
          source: atom()
        }

  @type t :: %__MODULE__{
          source: String.t(),
          primary_key: PrimaryKey.t(),
          foreign_keys: [ForeignKey.t()],
          fields: [Field.t()],
          indices: Indices.t()
        }

  defstruct [
    :source,
    :primary_key,
    :foreign_keys,
    :fields,
    :indices
  ]

  alias Ecto.Relation.Schema.Serializable

  use Serializable

  # defimpl JSON.Encoder do
  #   def encode(schema, opts) do
  #     JSON.Encoder.encode(
  #       Map.merge(
  #         %{
  #           __struct__: "Schema"
  #         },
  #         Map.from_struct(schema)
  #       ),
  #       opts
  #     )
  #   end
  # end

  @doc """
  Creates a new Schema struct with the provided metadata.

  ## Parameters

  - `source` - The table name
  - `primary_key` - Primary key information
  - `foreign_keys` - List of foreign key relationships
  - `fields` - List of field metadata
  - `indices` - Index information

  ## Examples

      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([:id])
      iex> indices = Ecto.Relation.Schema.Indices.new([])
      iex> schema = Ecto.Relation.Schema.new("users", pk, [], [], indices, [])
      iex> schema.source
      "users"
  """
  @spec new(
          String.t(),
          PrimaryKey.t(),
          [ForeignKey.t()],
          [Field.t()],
          Indices.t() | []
        ) :: t()
  def new(source, primary_key, foreign_keys, fields, indices) when is_list(indices) do
    new(source, primary_key, foreign_keys, fields, Indices.new(indices))
  end

  def new(source, primary_key, foreign_keys, fields, indices) do
    %__MODULE__{
      source: source,
      primary_key: primary_key,
      foreign_keys: foreign_keys,
      fields: fields,
      indices: indices
    }
  end

  @spec empty(String.t()) :: t()
  def empty(name) do
    new(name, nil, [], [], [])
  end

  @doc """
  Creates a Schema struct from an Ecto schema module.

  This function uses the MetadataExtractor to gather all available metadata
  from the Ecto schema and optionally from the database.

  ## Parameters

  - `schema_module` - The Ecto schema module
  - `repo` - The Ecto repository (optional, required for index introspection)

  ## Examples

      iex> schema = Ecto.Relation.Schema.from_ecto_schema(MyApp.User, MyApp.Repo)
      iex> schema.source
      "users"
  """
  @spec from_ecto_schema(module(), module() | nil) :: t()
  def from_ecto_schema(schema_module, repo \\ nil) when is_atom(schema_module) do
    alias Ecto.Relation.Schema.MetadataExtractor

    metadata = MetadataExtractor.extract_metadata(schema_module, repo)

    %__MODULE__{
      source: metadata.source,
      primary_key: metadata.primary_key,
      foreign_keys: metadata.foreign_keys,
      fields: metadata.fields,
      indices: metadata.indices
    }
  end

  defimpl Inspect do
    def inspect(%Ecto.Relation.Schema{} = schema, _opts) do
      fields_summary =
        schema.fields
        |> Enum.map(fn field -> "#{field.name}: #{inspect(field.ecto_type)}" end)
        |> Enum.join(", ")

      pk_summary =
        case schema.primary_key do
          nil ->
            "[]"

          %{fields: []} ->
            "[]"

          %{fields: fields} ->
            field_names =
              fields
              |> Enum.map(& &1.name)
              |> Enum.join(", ")

            "[#{field_names}]"
        end

      fk_summary =
        case schema.foreign_keys do
          [] ->
            "[]"

          fks ->
            fk_list =
              fks
              |> Enum.map(fn fk ->
                "#{fk.field} -> #{fk.references_table}.#{fk.references_field}"
              end)
              |> Enum.join(", ")

            "[#{fk_list}]"
        end

      indices_summary =
        case schema.indices.indices do
          [] ->
            "[]"

          indices ->
            indices_list =
              indices
              |> Enum.map(&inspect/1)
              |> Enum.join(", ")

            "[#{indices_list}]"
        end

      "#Ecto.Relation.Schema<" <>
        "source: #{inspect(schema.source)}, " <>
        "fields: [#{fields_summary}], " <>
        "primary_key: #{pk_summary}, " <>
        "foreign_keys: #{fk_summary}, " <>
        "indices: #{indices_summary}>"
    end
  end

  @doc """
  Finds a field by name in the schema.

  ## Examples

      iex> field = Ecto.Relation.Schema.find_field(schema, :email)
      iex> field.name
      :email
  """
  @spec find_field(t(), atom()) :: Field.t() | nil
  def find_field(%__MODULE__{fields: fields}, field_name) when is_atom(field_name) do
    Enum.find(fields, &Field.matches_name?(&1, field_name))
  end

  @doc """
  Checks if a field is a primary key field.

  ## Examples

      iex> Ecto.Relation.Schema.primary_key_field?(schema, :id)
      true
  """
  @spec primary_key_field?(t(), atom()) :: boolean()
  def primary_key_field?(%__MODULE__{primary_key: primary_key}, field_name)
      when is_atom(field_name) do
    field_name in PrimaryKey.field_names(primary_key)
  end

  @doc """
  Checks if a field is a foreign key field.

  ## Examples

      iex> Ecto.Relation.Schema.foreign_key_field?(schema, :user_id)
      true
  """
  @spec foreign_key_field?(t(), atom()) :: boolean()
  def foreign_key_field?(%__MODULE__{foreign_keys: foreign_keys}, field_name)
      when is_atom(field_name) do
    Enum.any?(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Gets the foreign key information for a specific field.

  ## Examples

      iex> fk = Ecto.Relation.Schema.get_foreign_key(schema, :user_id)
      iex> fk.references_table
      "users"
  """
  @spec get_foreign_key(t(), atom()) :: ForeignKey.t() | nil
  def get_foreign_key(%__MODULE__{foreign_keys: foreign_keys}, field_name)
      when is_atom(field_name) do
    Enum.find(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Checks if the schema has a composite primary key.

  ## Examples

      iex> Ecto.Relation.Schema.composite_primary_key?(schema)
      false
  """
  @spec composite_primary_key?(t()) :: boolean()
  def composite_primary_key?(%__MODULE__{primary_key: primary_key}) do
    PrimaryKey.composite?(primary_key)
  end

  @doc """
  Gets all field names in the schema.

  ## Examples

      iex> Ecto.Relation.Schema.field_names(schema)
      [:id, :name, :email, :created_at, :updated_at]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  @doc """
  Gets all foreign key field names in the schema.

  ## Examples

      iex> Ecto.Relation.Schema.foreign_key_field_names(schema)
      [:user_id, :category_id]
  """
  @spec foreign_key_field_names(t()) :: [atom()]
  def foreign_key_field_names(%__MODULE__{foreign_keys: foreign_keys}) do
    Enum.map(foreign_keys, & &1.field)
  end

  @doc """
  Gets the source table name for the schema.

  ## Examples

      iex> Ecto.Relation.Schema.source_table(schema)
      "users"
  """
  @spec source_table(t()) :: String.t()
  def source_table(%__MODULE__{source: source}) do
    source
  end

  # Access behavior implementation
  @behaviour Access

  @doc """
  Access behavior implementation for fetching fields by name.

  ## Examples

      iex> schema[:email]  # Returns the email field
      iex> schema[:id]     # Returns the id field
  """
  @impl Access
  def fetch(%__MODULE__{} = schema, key) when is_atom(key) do
    case find_field(schema, key) do
      nil -> :error
      field -> {:ok, field}
    end
  end

  def fetch(%__MODULE__{}, _key), do: :error

  @doc """
  Access behavior implementation for updating fields.

  ## Examples

      iex> get_and_update(schema, :email, fn field -> {field, %{field | type: :string}} end)
  """
  @impl Access
  def get_and_update(%__MODULE__{} = schema, key, function) when is_atom(key) do
    case find_field(schema, key) do
      nil ->
        {nil, schema}

      current_field ->
        case function.(current_field) do
          {get_value, new_field} ->
            updated_fields =
              Enum.map(schema.fields, fn field ->
                if field.name == key, do: new_field, else: field
              end)

            updated_schema = %{schema | fields: updated_fields}
            {get_value, updated_schema}

          :pop ->
            filtered_fields = Enum.reject(schema.fields, &(&1.name == key))
            updated_schema = %{schema | fields: filtered_fields}
            {current_field, updated_schema}
        end
    end
  end

  def get_and_update(%__MODULE__{} = schema, _key, _function) do
    {nil, schema}
  end

  @doc """
  Access behavior implementation for removing fields.

  ## Examples

      iex> pop(schema, :email)  # Removes and returns the email field
  """
  @impl Access
  def pop(%__MODULE__{} = schema, key) when is_atom(key) do
    case find_field(schema, key) do
      nil ->
        {nil, schema}

      field ->
        filtered_fields = Enum.reject(schema.fields, &(&1.name == key))
        updated_schema = %{schema | fields: filtered_fields}
        {field, updated_schema}
    end
  end

  def pop(%__MODULE__{} = schema, _key) do
    {nil, schema}
  end
end

# Enumerable protocol implementation for Schema
defimpl Enumerable, for: Ecto.Relation.Schema do
  @moduledoc """
  Enumerable protocol implementation for Ecto.Relation.Schema.

  Allows iterating over schema fields as {name, field} tuples and provides
  standard enumerable operations.
  """

  def count(%Ecto.Relation.Schema{fields: fields}) do
    {:ok, length(fields)}
  end

  def member?(%Ecto.Relation.Schema{} = schema, {key, field}) when is_atom(key) do
    case Ecto.Relation.Schema.find_field(schema, key) do
      ^field -> {:ok, true}
      _ -> {:ok, false}
    end
  end

  def member?(%Ecto.Relation.Schema{} = schema, key) when is_atom(key) do
    case Ecto.Relation.Schema.find_field(schema, key) do
      nil -> {:ok, false}
      _ -> {:ok, true}
    end
  end

  def member?(%Ecto.Relation.Schema{}, _element) do
    {:ok, false}
  end

  def slice(%Ecto.Relation.Schema{fields: fields}) do
    field_tuples = Enum.map(fields, fn field -> {field.name, field} end)
    {:ok, length(field_tuples), &Enum.slice(field_tuples, &1, &2)}
  end

  def reduce(%Ecto.Relation.Schema{fields: fields}, acc, fun) do
    field_tuples = Enum.map(fields, fn field -> {field.name, field} end)
    Enumerable.reduce(field_tuples, acc, fun)
  end
end
