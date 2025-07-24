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
