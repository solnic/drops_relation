defmodule Drops.Relation.Schema.ForeignKey do
  @moduledoc """
  Represents a foreign key relationship in a database table/schema.

  This struct stores information about a foreign key field and its reference
  to another table and field.

  ## Examples

      # Simple foreign key
      %Drops.Relation.Schema.ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id
      }
  """

  @type t :: %__MODULE__{
          field: atom(),
          references_table: String.t(),
          references_field: atom()
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct [:field, :references_table, :references_field]

  @doc """
  Creates a new ForeignKey struct.

  ## Parameters

  - `field` - The foreign key field name in the current table
  - `references_table` - The name of the referenced table
  - `references_field` - The field name in the referenced table

  ## Examples

      iex> Drops.Relation.Schema.ForeignKey.new(:user_id, "users", :id, :user)
      %Drops.Relation.Schema.ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id
      }
  """
  @spec new(atom(), String.t(), atom()) :: t()
  def new(field, references_table, references_field) do
    %__MODULE__{
      field: field,
      references_table: references_table,
      references_field: references_field
    }
  end
end

# Enumerable protocol implementation for ForeignKey
defimpl Enumerable, for: Drops.Relation.Schema.ForeignKey do
  @moduledoc """
  Enumerable protocol implementation for Drops.Relation.Schema.ForeignKey.

  Returns a tuple structure for compiler processing:
  `{:foreign_key, [field, references_table, references_field]}`

  This enables the compiler to process foreign keys using pattern matching
  on tagged tuples following the visitor pattern.
  """

  def count(%Drops.Relation.Schema.ForeignKey{}) do
    {:ok, 1}
  end

  def member?(%Drops.Relation.Schema.ForeignKey{} = fk, element) do
    tuple_representation = {:foreign_key, [fk.field, fk.references_table, fk.references_field]}

    {:ok, element == tuple_representation}
  end

  def slice(%Drops.Relation.Schema.ForeignKey{} = fk) do
    tuple_representation = {:foreign_key, [fk.field, fk.references_table, fk.references_field]}

    {:ok, 1,
     fn
       0, 1, _step -> [tuple_representation]
       _, _, _ -> []
     end}
  end

  def reduce(%Drops.Relation.Schema.ForeignKey{} = fk, acc, fun) do
    tuple_representation = {:foreign_key, [fk.field, fk.references_table, fk.references_field]}

    Enumerable.reduce([tuple_representation], acc, fun)
  end
end
