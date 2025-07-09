defmodule Drops.Relation.SQL.Database.PrimaryKey do
  @moduledoc """
  Represents a primary key constraint in a database table.

  This struct stores information about primary key columns, supporting both
  single-column and composite primary keys. The columns attribute contains
  the names of columns that form the primary key.

  ## Examples

      # Single primary key
      %Drops.Relation.SQL.Database.PrimaryKey{
        columns: ["id"]
      }

      # Composite primary key
      %Drops.Relation.SQL.Database.PrimaryKey{
        columns: ["user_id", "role_id"]
      }

      # No primary key
      %Drops.Relation.SQL.Database.PrimaryKey{
        columns: []
      }
  """

  @type t :: %__MODULE__{
          columns: [String.t()]
        }

  defstruct columns: []

  @doc """
  Creates a new PrimaryKey struct.

  ## Parameters

  - `columns` - List of column names that form the primary key

  ## Examples

      iex> Drops.Relation.SQL.Database.PrimaryKey.new(["id"])
      %Drops.Relation.SQL.Database.PrimaryKey{columns: ["id"]}

      iex> Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      %Drops.Relation.SQL.Database.PrimaryKey{columns: ["user_id", "role_id"]}

      iex> Drops.Relation.SQL.Database.PrimaryKey.new([])
      %Drops.Relation.SQL.Database.PrimaryKey{columns: []}
  """
  @spec new([String.t()]) :: t()
  def new(columns) when is_list(columns) do
    %__MODULE__{columns: columns}
  end

  @doc """
  Creates a PrimaryKey struct from a list of Column structs.

  Extracts the names of columns that are marked as primary key columns.

  ## Parameters

  - `columns` - List of Column structs

  ## Examples

      iex> alias Drops.Relation.SQL.Database.Column
      iex> columns = [
      ...>   Column.new("id", "integer", false, nil, true),
      ...>   Column.new("name", "varchar(255)", true, nil, false)
      ...> ]
      iex> Drops.Relation.SQL.Database.PrimaryKey.from_columns(columns)
      %Drops.Relation.SQL.Database.PrimaryKey{columns: ["id"]}
  """
  @spec from_columns([Drops.Relation.SQL.Database.Column.t()]) :: t()
  def from_columns(columns) when is_list(columns) do
    primary_key_columns =
      columns
      |> Enum.filter(&Drops.Relation.SQL.Database.Column.primary_key?/1)
      |> Enum.map(& &1.name)

    new(primary_key_columns)
  end

  @doc """
  Checks if the primary key is composite (has multiple columns).

  ## Examples

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.composite?(pk)
      false

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.composite?(pk)
      true

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new([])
      iex> Drops.Relation.SQL.Database.PrimaryKey.composite?(pk)
      false
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{columns: columns}) do
    length(columns) > 1
  end

  @doc """
  Checks if the table has a primary key.

  ## Examples

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.present?(pk)
      true

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new([])
      iex> Drops.Relation.SQL.Database.PrimaryKey.present?(pk)
      false
  """
  @spec present?(t()) :: boolean()
  def present?(%__MODULE__{columns: columns}) do
    columns != []
  end

  @doc """
  Gets the column names that form the primary key.

  ## Examples

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.column_names(pk)
      ["user_id", "role_id"]

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new([])
      iex> Drops.Relation.SQL.Database.PrimaryKey.column_names(pk)
      []
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}), do: columns

  @doc """
  Checks if a specific column is part of the primary key.

  ## Examples

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.includes_column?(pk, "user_id")
      true

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.includes_column?(pk, "name")
      false
  """
  @spec includes_column?(t(), String.t()) :: boolean()
  def includes_column?(%__MODULE__{columns: columns}, column_name)
      when is_binary(column_name) do
    column_name in columns
  end

  @doc """
  Gets the number of columns in the primary key.

  ## Examples

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Drops.Relation.SQL.Database.PrimaryKey.column_count(pk)
      2

      iex> pk = Drops.Relation.SQL.Database.PrimaryKey.new([])
      iex> Drops.Relation.SQL.Database.PrimaryKey.column_count(pk)
      0
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end

defimpl Drops.Relation.Schema.Field.Inference, for: Drops.Relation.SQL.Database.PrimaryKey do
  @moduledoc """
  Implementation of Drops.Relation.Schema.Inference protocol for PrimaryKey structs.

  Converts database PrimaryKey structs to Drops.Relation.Schema.PrimaryKey structs
  using the provided column context.
  """

  alias Drops.Relation.Schema

  def to_schema_field(%Drops.Relation.SQL.Database.PrimaryKey{} = primary_key, table) do
    pk_fields = Enum.filter(table.columns, fn column -> column.name in primary_key.columns end)

    Schema.PrimaryKey.new(Enum.map(pk_fields, &Schema.Field.Inference.to_schema_field(&1, table)))
  end
end
