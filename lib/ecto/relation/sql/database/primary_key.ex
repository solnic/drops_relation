defmodule Ecto.Relation.SQL.Database.PrimaryKey do
  @moduledoc """
  Represents a primary key constraint in a database table.

  This struct stores information about primary key columns, supporting both
  single-column and composite primary keys. The columns attribute contains
  the names of columns that form the primary key.

  ## Examples

      # Single primary key
      %Ecto.Relation.SQL.Database.PrimaryKey{
        columns: ["id"]
      }

      # Composite primary key
      %Ecto.Relation.SQL.Database.PrimaryKey{
        columns: ["user_id", "role_id"]
      }

      # No primary key
      %Ecto.Relation.SQL.Database.PrimaryKey{
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

      iex> Ecto.Relation.SQL.Database.PrimaryKey.new(["id"])
      %Ecto.Relation.SQL.Database.PrimaryKey{columns: ["id"]}

      iex> Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      %Ecto.Relation.SQL.Database.PrimaryKey{columns: ["user_id", "role_id"]}

      iex> Ecto.Relation.SQL.Database.PrimaryKey.new([])
      %Ecto.Relation.SQL.Database.PrimaryKey{columns: []}
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

      iex> alias Ecto.Relation.SQL.Database.Column
      iex> columns = [
      ...>   Column.new("id", "integer", false, nil, true),
      ...>   Column.new("name", "varchar(255)", true, nil, false)
      ...> ]
      iex> Ecto.Relation.SQL.Database.PrimaryKey.from_columns(columns)
      %Ecto.Relation.SQL.Database.PrimaryKey{columns: ["id"]}
  """
  @spec from_columns([Ecto.Relation.SQL.Database.Column.t()]) :: t()
  def from_columns(columns) when is_list(columns) do
    primary_key_columns =
      columns
      |> Enum.filter(&Ecto.Relation.SQL.Database.Column.primary_key?/1)
      |> Enum.map(& &1.name)

    new(primary_key_columns)
  end

  @doc """
  Checks if the primary key is composite (has multiple columns).

  ## Examples

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.composite?(pk)
      false

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.composite?(pk)
      true

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new([])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.composite?(pk)
      false
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{columns: columns}) do
    length(columns) > 1
  end

  @doc """
  Checks if the table has a primary key.

  ## Examples

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.present?(pk)
      true

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new([])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.present?(pk)
      false
  """
  @spec present?(t()) :: boolean()
  def present?(%__MODULE__{columns: columns}) do
    columns != []
  end

  @doc """
  Gets the column names that form the primary key.

  ## Examples

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.column_names(pk)
      ["user_id", "role_id"]

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new([])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.column_names(pk)
      []
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}), do: columns

  @doc """
  Checks if a specific column is part of the primary key.

  ## Examples

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.includes_column?(pk, "user_id")
      true

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.includes_column?(pk, "name")
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

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new(["user_id", "role_id"])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.column_count(pk)
      2

      iex> pk = Ecto.Relation.SQL.Database.PrimaryKey.new([])
      iex> Ecto.Relation.SQL.Database.PrimaryKey.column_count(pk)
      0
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end

defimpl Ecto.Relation.Schema.Field.Inference, for: Ecto.Relation.SQL.Database.PrimaryKey do
  @moduledoc """
  Implementation of Ecto.Relation.Schema.Inference protocol for PrimaryKey structs.

  Converts database PrimaryKey structs to Ecto.Relation.Schema.PrimaryKey structs
  using the provided column context.
  """

  alias Ecto.Relation.Schema

  def to_schema_field(%Ecto.Relation.SQL.Database.PrimaryKey{} = primary_key, table) do
    pk_fields = Enum.filter(table.columns, fn column -> column.name in primary_key.columns end)

    Schema.PrimaryKey.new(Enum.map(pk_fields, &Schema.Field.Inference.to_schema_field(&1, table)))
  end
end
