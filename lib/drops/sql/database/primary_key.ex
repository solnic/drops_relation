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
      iex> col = Column.new("id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col])
      iex> length(pk.columns)
      1
      iex> pk.meta.composite
      false

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
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

  @doc """
  Creates a PrimaryKey struct from a list of Column structs.

  Extracts the columns that are marked as primary key columns.

  ## Parameters

  - `columns` - List of Column structs

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> columns = [
      ...>   Column.new("id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []}),
      ...>   Column.new("name", "varchar(255)", %{nullable: true, default: nil, primary_key: false, check_constraints: []})
      ...> ]
      iex> pk = Drops.SQL.Database.PrimaryKey.from_columns(columns)
      iex> length(pk.columns)
      1
      iex> hd(pk.columns).name
      "id"
  """
  @spec from_columns([Column.t()]) :: t()
  def from_columns(columns) when is_list(columns) do
    primary_key_columns = Enum.filter(columns, &Column.primary_key?/1)
    new(primary_key_columns)
  end

  @doc """
  Checks if the primary key is composite (has multiple columns).

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> col = Column.new("id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col])
      iex> Drops.SQL.Database.PrimaryKey.composite?(pk)
      false

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> Drops.SQL.Database.PrimaryKey.composite?(pk)
      true

      iex> pk = Drops.SQL.Database.PrimaryKey.new([])
      iex> Drops.SQL.Database.PrimaryKey.composite?(pk)
      false
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{meta: %{composite: composite}}) do
    composite
  end

  @doc """
  Checks if the table has a primary key.

  ## Examples

      iex> pk = Drops.SQL.Database.PrimaryKey.new(["id"])
      iex> Drops.SQL.Database.PrimaryKey.present?(pk)
      true

      iex> pk = Drops.SQL.Database.PrimaryKey.new([])
      iex> Drops.SQL.Database.PrimaryKey.present?(pk)
      false
  """
  @spec present?(t()) :: boolean()
  def present?(%__MODULE__{columns: columns}) do
    columns != []
  end

  @doc """
  Gets the column names that form the primary key.

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> Drops.SQL.Database.PrimaryKey.column_names(pk)
      ["user_id", "role_id"]

      iex> pk = Drops.SQL.Database.PrimaryKey.new([])
      iex> Drops.SQL.Database.PrimaryKey.column_names(pk)
      []
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}) do
    Enum.map(columns, & &1.name)
  end

  @doc """
  Checks if a specific column is part of the primary key.

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> Drops.SQL.Database.PrimaryKey.includes_column?(pk, "user_id")
      true

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> Drops.SQL.Database.PrimaryKey.includes_column?(pk, "name")
      false
  """
  @spec includes_column?(t(), String.t()) :: boolean()
  def includes_column?(%__MODULE__{columns: columns}, column_name)
      when is_binary(column_name) do
    Enum.any?(columns, &(&1.name == column_name))
  end

  @doc """
  Gets the number of columns in the primary key.

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> col1 = Column.new("user_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> col2 = Column.new("role_id", "integer", %{nullable: false, default: nil, primary_key: true, check_constraints: []})
      iex> pk = Drops.SQL.Database.PrimaryKey.new([col1, col2])
      iex> Drops.SQL.Database.PrimaryKey.column_count(pk)
      2

      iex> pk = Drops.SQL.Database.PrimaryKey.new([])
      iex> Drops.SQL.Database.PrimaryKey.column_count(pk)
      0
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end
