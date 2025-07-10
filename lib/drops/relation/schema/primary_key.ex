defmodule Drops.Relation.Schema.PrimaryKey do
  @moduledoc """
  Represents primary key information for a database table/schema.

  This struct stores information about primary key fields, supporting both
  single-column and composite primary keys. Fields are stored as Field structs
  containing complete metadata.

  ## Examples

      # Single primary key
      %Drops.Relation.Schema.PrimaryKey{
        fields: [%Drops.Relation.Schema.Field{name: :id, type: :integer, ...}]
      }

      # Composite primary key
      %Drops.Relation.Schema.PrimaryKey{
        fields: [
          %Drops.Relation.Schema.Field{name: :user_id, type: :integer, ...},
          %Drops.Relation.Schema.Field{name: :role_id, type: :integer, ...}
        ]
      }

      # No primary key
      %Drops.Relation.Schema.PrimaryKey{fields: []}
  """

  alias Drops.Relation.Schema.Field

  @type t :: %__MODULE__{
          fields: [Field.t()]
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct [:fields]

  @doc """
  Creates a new PrimaryKey struct.

  ## Parameters

  - `fields` - List of Field structs that form the primary key

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field])
      iex> length(pk.fields)
      1
  """
  @spec new([Field.t()]) :: t()
  def new(fields) when is_list(fields) do
    %__MODULE__{fields: fields}
  end

  defimpl Inspect do
    def inspect(%Drops.Relation.Schema.PrimaryKey{} = pk, _opts) do
      case pk.fields do
        [] ->
          "#PrimaryKey<[]>"

        fields ->
          field_names =
            fields
            |> Enum.map(& &1.name)
            |> Enum.join(", ")

          "#PrimaryKey<[#{field_names}]>"
      end
    end
  end

  @doc """
  Checks if the primary key is composite (has multiple fields).

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field])
      iex> Drops.Relation.Schema.PrimaryKey.composite?(pk)
      false

      iex> field1 = Drops.Relation.Schema.Field.new(:user_id, :integer, :id, :user_id)
      iex> field2 = Drops.Relation.Schema.Field.new(:role_id, :integer, :id, :role_id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field1, field2])
      iex> Drops.Relation.Schema.PrimaryKey.composite?(pk)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{fields: fields}) do
    length(fields) > 1
  end

  @doc """
  Checks if the schema has a primary key.

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field])
      iex> Drops.Relation.Schema.PrimaryKey.present?(pk)
      true

      iex> pk = Drops.Relation.Schema.PrimaryKey.new([])
      iex> Drops.Relation.Schema.PrimaryKey.present?(pk)
      false
  """
  @spec present?(t()) :: boolean()
  def present?(%__MODULE__{fields: fields}) do
    fields != []
  end

  @doc """
  Gets the field names from the primary key.

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field])
      iex> Drops.Relation.Schema.PrimaryKey.field_names(pk)
      [:id]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  @doc """
  Merges two primary keys, with the right primary key taking precedence.

  ## Parameters

  - `left` - The base primary key
  - `right` - The primary key to merge into the base, takes precedence

  ## Returns

  A merged Drops.Relation.Schema.PrimaryKey.t() struct.

  ## Examples

      iex> left = Drops.Relation.Schema.PrimaryKey.new([field1])
      iex> right = Drops.Relation.Schema.PrimaryKey.new([field2])
      iex> merged = Drops.Relation.Schema.PrimaryKey.merge(left, right)
      iex> length(merged.fields)
      1
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = _left, %__MODULE__{} = right) do
    # Right takes precedence for primary key
    right
  end
end

# Enumerable protocol implementation for PrimaryKey
defimpl Enumerable, for: Drops.Relation.Schema.PrimaryKey do
  @moduledoc """
  Enumerable protocol implementation for Drops.Relation.Schema.PrimaryKey.

  Returns a tuple structure for compiler processing:
  `{:primary_key, [name, columns]}` where columns are field names

  This enables the compiler to process primary keys using pattern matching
  on tagged tuples following the visitor pattern.
  """

  def count(%Drops.Relation.Schema.PrimaryKey{}) do
    {:ok, 1}
  end

  def member?(%Drops.Relation.Schema.PrimaryKey{} = pk, element) do
    columns = Enum.map(pk.fields, & &1.name)
    name = generate_primary_key_name(columns)
    tuple_representation = {:primary_key, [name, columns]}
    {:ok, element == tuple_representation}
  end

  def slice(%Drops.Relation.Schema.PrimaryKey{} = pk) do
    columns = Enum.map(pk.fields, & &1.name)
    name = generate_primary_key_name(columns)
    tuple_representation = {:primary_key, [name, columns]}

    {:ok, 1,
     fn
       0, 1, _step -> [tuple_representation]
       _, _, _ -> []
     end}
  end

  def reduce(%Drops.Relation.Schema.PrimaryKey{} = pk, acc, fun) do
    columns = Enum.map(pk.fields, & &1.name)
    name = generate_primary_key_name(columns)
    tuple_representation = {:primary_key, [name, columns]}
    Enumerable.reduce([tuple_representation], acc, fun)
  end

  # Helper function to generate primary key name
  defp generate_primary_key_name([]), do: nil
  defp generate_primary_key_name([single_column]), do: single_column

  defp generate_primary_key_name(columns) when is_list(columns) do
    # For composite primary keys, create a descriptive name
    columns
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join("_")
    |> then(&"#{&1}_pk")
    |> String.to_atom()
  end
end
