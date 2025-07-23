defmodule Drops.SQL.Database.PrimaryKey do
  @moduledoc """
  Represents a primary key constraint in a database table.

  This struct stores information about primary key columns, supporting both
  single-column and composite primary keys. The columns attribute contains
  the actual Column structs that form the primary key, and meta contains
  additional information including whether it's a composite key.

  ## Examples

      # Single primary key
      %Drops.SQL.Database.PrimaryKey{
        columns: [%Drops.SQL.Database.Column{name: "id", ...}],
        meta: %{composite: false}
      }

      # Composite primary key
      %Drops.SQL.Database.PrimaryKey{
        columns: [
          %Drops.SQL.Database.Column{name: "user_id", ...},
          %Drops.SQL.Database.Column{name: "role_id", ...}
        ],
        meta: %{composite: true}
      }

      # No primary key
      %Drops.SQL.Database.PrimaryKey{
        columns: [],
        meta: %{composite: false}
      }
  """

  alias Drops.SQL.Database.Column

  @type meta :: %{
          composite: boolean()
        }

  @type t :: %__MODULE__{
          columns: [Column.t()],
          meta: meta()
        }

  defstruct columns: [], meta: %{composite: false}

  @doc """
  Creates a new PrimaryKey struct.

  ## Parameters

  - `columns` - List of Column structs that form the primary key

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> col = Column.new("id", :integer, %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col])
      iex> length(pk.columns)
      1
      iex> pk.meta.composite
      false

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", :integer, %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", :integer, %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> length(pk.columns)
      2
      iex> pk.meta.composite
      true

      iex> Drops.SQL.Database.PrimaryKey.new([])
      %Drops.SQL.Database.PrimaryKey{columns: [], meta: %{composite: false}}
  """
  @spec new([Column.t()]) :: t()
  def new(columns) when is_list(columns) do
    composite = length(columns) > 1
    %__MODULE__{columns: columns, meta: %{composite: composite}}
  end
end
