defmodule Drops.Relation.Schema.Index do
  @moduledoc """
  Represents a database index on a table.

  This struct stores information about a database index including its name,
  the fields it covers, whether it's unique, and its type. Fields are stored
  as Field structs containing complete metadata.

  ## Examples

      # Simple index
      %Drops.Relation.Schema.Index{
        name: "users_email_index",
        fields: [%Drops.Relation.Schema.Field{name: :email, ...}],
        unique: true,
        type: :btree
      }

      # Composite index
      %Drops.Relation.Schema.Index{
        name: "users_name_email_index",
        fields: [
          %Drops.Relation.Schema.Field{name: :name, ...},
          %Drops.Relation.Schema.Field{name: :email, ...}
        ],
        unique: false,
        type: :btree
      }
  """

  alias Drops.Relation.Schema.Field

  @type index_type :: :btree | :hash | :gin | :gist | :brin | nil

  @type t :: %__MODULE__{
          name: String.t(),
          fields: [Field.t()],
          unique: boolean(),
          type: index_type()
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct [:name, :fields, :unique, :type]

  @doc """
  Creates a new Index struct.

  ## Parameters

  - `name` - The index name
  - `fields` - List of Field structs covered by the index
  - `unique` - Whether the index enforces uniqueness
  - `type` - The index type (optional)

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Drops.Relation.Schema.Index.new("users_email_index", [field], true, :btree)
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
  Checks if the index is composite (covers multiple fields).

  ## Examples

      iex> index = Drops.Relation.Schema.Index.new("single_field", [:email], true)
      iex> Drops.Relation.Schema.Index.composite?(index)
      false

      iex> index = Drops.Relation.Schema.Index.new("multi_field", [:name, :email], false)
      iex> Drops.Relation.Schema.Index.composite?(index)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{fields: fields}) do
    length(fields) > 1
  end

  @doc """
  Gets the field names from the index.

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Drops.Relation.Schema.Index.new("users_email_index", [field], true)
      iex> Drops.Relation.Schema.Index.field_names(index)
      [:email]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  @doc """
  Checks if the index covers a specific field.

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> index = Drops.Relation.Schema.Index.new("users_email_index", [field], true)
      iex> Drops.Relation.Schema.Index.covers_field?(index, :email)
      true

      iex> Drops.Relation.Schema.Index.covers_field?(index, :name)
      false
  """
  @spec covers_field?(t(), atom()) :: boolean()
  def covers_field?(%__MODULE__{fields: fields}, field_name) when is_atom(field_name) do
    Enum.any?(fields, &Field.matches_name?(&1, field_name))
  end
end

# Enumerable protocol implementation for Index
defimpl Enumerable, for: Drops.Relation.Schema.Index do
  @moduledoc """
  Enumerable protocol implementation for Drops.Relation.Schema.Index.

  Returns a tuple structure for compiler processing:
  `{:index, [name, columns, unique, type]}` where columns are field names

  This enables the compiler to process indices using pattern matching
  on tagged tuples following the visitor pattern.
  """

  def count(%Drops.Relation.Schema.Index{}) do
    {:ok, 1}
  end

  def member?(%Drops.Relation.Schema.Index{} = index, element) do
    columns = Enum.map(index.fields, & &1.name)
    tuple_representation = {:index, [index.name, columns, index.unique, index.type]}
    {:ok, element == tuple_representation}
  end

  def slice(%Drops.Relation.Schema.Index{} = index) do
    columns = Enum.map(index.fields, & &1.name)
    tuple_representation = {:index, [index.name, columns, index.unique, index.type]}

    {:ok, 1,
     fn
       0, 1, _step -> [tuple_representation]
       _, _, _ -> []
     end}
  end

  def reduce(%Drops.Relation.Schema.Index{} = index, acc, fun) do
    columns = Enum.map(index.fields, & &1.name)
    tuple_representation = {:index, [index.name, columns, index.unique, index.type]}
    Enumerable.reduce([tuple_representation], acc, fun)
  end
end
