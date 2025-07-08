defmodule Ecto.Relation.Schema.Index do
  @moduledoc """
  Represents a database index on a table.

  This struct stores information about a database index including its name,
  the fields it covers, whether it's unique, and its type. Fields are stored
  as Field structs containing complete metadata.

  ## Examples

      # Simple index
      %Ecto.Relation.Schema.Index{
        name: "users_email_index",
        fields: [%Ecto.Relation.Schema.Field{name: :email, ...}],
        unique: true,
        type: :btree
      }

      # Composite index
      %Ecto.Relation.Schema.Index{
        name: "users_name_email_index",
        fields: [
          %Ecto.Relation.Schema.Field{name: :name, ...},
          %Ecto.Relation.Schema.Field{name: :email, ...}
        ],
        unique: false,
        type: :btree
      }
  """

  alias Ecto.Relation.Schema.Field

  @type index_type :: :btree | :hash | :gin | :gist | :brin | nil

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [Field.t()],
          unique: boolean(),
          type: index_type()
        }

  defstruct [:name, :fields, :unique, :type]

  @doc """
  Creates a new Index struct.

  ## Parameters

  - `name` - The index name
  - `fields` - List of Field structs covered by the index
  - `unique` - Whether the index enforces uniqueness
  - `type` - The index type (optional)

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Ecto.Relation.Schema.Index.new("users_email_index", [field], true, :btree)
      iex> index.name
      "users_email_index"
      iex> index.unique
      true
  """
  @spec new(String.t(), [Field.t()], boolean(), index_type()) :: t()
  def new(name, fields, unique \\ false, type \\ nil) do
    %__MODULE__{
      name: name,
      fields: fields,
      unique: unique,
      type: type
    }
  end

  @doc """
  Creates a new Index struct from field names.

  This is a convenience function for backward compatibility and simple cases.

  ## Parameters

  - `name` - The index name
  - `field_names` - List of field names covered by the index
  - `unique` - Whether the index enforces uniqueness
  - `type` - The index type (optional)

  ## Examples

      iex> index = Ecto.Relation.Schema.Index.from_names("users_email_index", [:email], true, :btree)
      iex> index.name
      "users_email_index"
      iex> [field] = index.fields
      iex> field.name
      :email
  """
  @spec from_names(String.t(), [atom()], boolean(), index_type()) :: t()
  def from_names(name, field_names, unique \\ false, type \\ nil) do
    fields =
      Enum.map(field_names, fn field_name ->
        # Create minimal Field structs for backward compatibility
        Field.new(field_name, :unknown, :unknown, field_name)
      end)

    new(name, fields, unique, type)
  end

  @doc """
  Checks if the index is composite (covers multiple fields).

  ## Examples

      iex> index = Ecto.Relation.Schema.Index.new("single_field", [:email], true)
      iex> Ecto.Relation.Schema.Index.composite?(index)
      false

      iex> index = Ecto.Relation.Schema.Index.new("multi_field", [:name, :email], false)
      iex> Ecto.Relation.Schema.Index.composite?(index)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{fields: fields}) do
    length(fields) > 1
  end

  @doc """
  Gets the field names from the index.

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Ecto.Relation.Schema.Index.new("users_email_index", [field], true)
      iex> Ecto.Relation.Schema.Index.field_names(index)
      [:email]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  defimpl Inspect do
    def inspect(%Ecto.Relation.Schema.Index{} = index, _opts) do
      field_names =
        index.fields
        |> Enum.map(& &1.name)
        |> Enum.join(", ")

      unique_marker = if index.unique, do: " (unique)", else: ""
      type_info = if index.type, do: " #{index.type}", else: ""

      "#Index<#{index.name}: [#{field_names}]#{unique_marker}#{type_info}>"
    end
  end

  @doc """
  Checks if the index covers a specific field.

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Ecto.Relation.Schema.Index.new("users_email_index", [field], true)
      iex> Ecto.Relation.Schema.Index.covers_field?(index, :email)
      true

      iex> Ecto.Relation.Schema.Index.covers_field?(index, :name)
      false
  """
  @spec covers_field?(t(), atom()) :: boolean()
  def covers_field?(%__MODULE__{fields: fields}, field_name) when is_atom(field_name) do
    Enum.any?(fields, &Field.matches_name?(&1, field_name))
  end
end
