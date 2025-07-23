defmodule Drops.SQL.Database.Index do
  @moduledoc """
  Represents a database index with complete metadata.

  This struct stores comprehensive information about a database index including
  its name, columns, type, and properties extracted from database introspection.

  ## Examples

      # Simple index
      %Drops.SQL.Database.Index{
        name: "idx_users_email",
        columns: ["email"],
        unique: true,
        type: :btree
      }

      # Composite index
      %Drops.SQL.Database.Index{
        name: "idx_users_name_age",
        columns: ["name", "age"],
        unique: false,
        type: :btree
      }

      # Partial index
      %Drops.SQL.Database.Index{
        name: "idx_users_active_email",
        columns: ["email"],
        unique: true,
        type: :btree,
        where_clause: "active = true"
      }
  """

  @type index_type :: :btree | :hash | :gin | :gist | :brin | :unknown

  @type meta :: %{
          unique: boolean(),
          type: index_type(),
          where_clause: String.t() | nil
        }

  @type t :: %__MODULE__{
          name: String.t(),
          columns: [String.t()]
        }

  defstruct [:name, :columns, :meta]

  @doc """
  Creates a new Index struct.

  ## Parameters

  - `name` - The index name
  - `columns` - List of column names in the index
  - `unique` - Whether the index enforces uniqueness
  - `type` - The index type (e.g., :btree, :hash, :gin)
  - `where_clause` - Optional WHERE clause for partial indices

  ## Examples

      iex> Drops.SQL.Database.Index.new("idx_users_email", ["email"], true, :btree)
      %Drops.SQL.Database.Index{
        name: "idx_users_email",
        columns: ["email"],
        unique: true,
        type: :btree,
        where_clause: nil
      }

      iex> Drops.SQL.Database.Index.new(
      ...>   "idx_users_active_email",
      ...>   ["email"],
      ...>   true,
      ...>   :btree,
      ...>   "active = true"
      ...> )
      %Drops.SQL.Database.Index{
        name: "idx_users_active_email",
        columns: ["email"],
        unique: true,
        type: :btree,
        where_clause: "active = true"
      }
  """
  @spec new(String.t(), [String.t()], meta()) :: t()
  def new(name, columns, meta) do
    %__MODULE__{name: name, columns: columns, meta: meta}
  end
end
