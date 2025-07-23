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

  @type meta :: %{
          composite: boolean()
        }

  @type t :: %__MODULE__{
          fields: [Field.t()],
          meta: meta()
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct fields: [], meta: %{composite: false}

  @doc """
  Creates a new PrimaryKey struct.

  ## Parameters

  - `fields` - List of Field structs that form the primary key

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Drops.Relation.Schema.PrimaryKey.new([field])
      iex> length(pk.fields)
      1
      iex> pk.meta.composite
      false
  """
  @spec new([Field.t()]) :: t()
  def new(fields) when is_list(fields) do
    composite = length(fields) > 1
    %__MODULE__{fields: fields, meta: %{composite: composite}}
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
  def composite?(%__MODULE__{meta: %{composite: composite}}) do
    composite
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
