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
          type: index_type(),
          composite: boolean()
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct [:name, :fields, :unique, :type, :composite]

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
      type: type,
      composite: length(fields) > 1
    }
  end
end
