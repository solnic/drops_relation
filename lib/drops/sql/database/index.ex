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

  @type t :: %__MODULE__{
          name: String.t(),
          columns: [String.t()],
          unique: boolean(),
          type: index_type(),
          where_clause: String.t() | nil
        }

  defstruct [
    :name,
    :columns,
    :unique,
    :type,
    :where_clause
  ]

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
  @spec new(String.t(), [String.t()], boolean(), index_type(), String.t() | nil) :: t()
  def new(name, columns, unique, type, where_clause \\ nil) do
    %__MODULE__{
      name: name,
      columns: columns,
      unique: unique,
      type: type,
      where_clause: where_clause
    }
  end

  @doc """
  Creates an Index struct from introspection data.

  This is a convenience function for creating indices from the raw data
  returned by database introspection queries.

  ## Parameters

  - `introspection_data` - A map with index metadata from database introspection

  ## Examples

      iex> data = %{
      ...>   name: "idx_users_email",
      ...>   columns: ["email"],
      ...>   unique: true,
      ...>   type: :btree,
      ...>   where_clause: nil
      ...> }
      iex> Drops.SQL.Database.Index.from_introspection(data)
      %Drops.SQL.Database.Index{
        name: "idx_users_email",
        columns: ["email"],
        unique: true,
        type: :btree,
        where_clause: nil
      }
  """
  @spec from_introspection(map()) :: t()
  def from_introspection(data) when is_map(data) do
    %__MODULE__{
      name: Map.get(data, :name) || Map.get(data, "name"),
      columns: Map.get(data, :columns, []) || Map.get(data, "columns", []),
      unique: Map.get(data, :unique, false) || Map.get(data, "unique", false),
      type: Map.get(data, :type, :unknown) || Map.get(data, "type", :unknown),
      where_clause: Map.get(data, :where_clause) || Map.get(data, "where_clause")
    }
  end

  @doc """
  Checks if the index is composite (has multiple columns).

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_email", ["email"], true, :btree)
      iex> Drops.SQL.Database.Index.composite?(index)
      false

      iex> index = Drops.SQL.Database.Index.new("idx_users_name_age", ["name", "age"], false, :btree)
      iex> Drops.SQL.Database.Index.composite?(index)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{columns: columns}) do
    length(columns) > 1
  end

  @doc """
  Checks if the index is unique.

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_email", ["email"], true, :btree)
      iex> Drops.SQL.Database.Index.unique?(index)
      true

      iex> index = Drops.SQL.Database.Index.new("idx_users_name", ["name"], false, :btree)
      iex> Drops.SQL.Database.Index.unique?(index)
      false
  """
  @spec unique?(t()) :: boolean()
  def unique?(%__MODULE__{unique: unique}), do: unique

  @doc """
  Checks if the index is partial (has a WHERE clause).

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_active_email", ["email"], true, :btree, "active = true")
      iex> Drops.SQL.Database.Index.partial?(index)
      true

      iex> index = Drops.SQL.Database.Index.new("idx_users_email", ["email"], true, :btree)
      iex> Drops.SQL.Database.Index.partial?(index)
      false
  """
  @spec partial?(t()) :: boolean()
  def partial?(%__MODULE__{where_clause: where_clause}), do: not is_nil(where_clause)

  @doc """
  Gets the column names that form the index.

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_name_age", ["name", "age"], false, :btree)
      iex> Drops.SQL.Database.Index.column_names(index)
      ["name", "age"]
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}), do: columns

  @doc """
  Checks if a specific column is part of the index.

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_name_age", ["name", "age"], false, :btree)
      iex> Drops.SQL.Database.Index.includes_column?(index, "name")
      true

      iex> index = Drops.SQL.Database.Index.new("idx_users_name_age", ["name", "age"], false, :btree)
      iex> Drops.SQL.Database.Index.includes_column?(index, "email")
      false
  """
  @spec includes_column?(t(), String.t()) :: boolean()
  def includes_column?(%__MODULE__{columns: columns}, column_name)
      when is_binary(column_name) do
    column_name in columns
  end

  @doc """
  Gets the number of columns in the index.

  ## Examples

      iex> index = Drops.SQL.Database.Index.new("idx_users_name_age", ["name", "age"], false, :btree)
      iex> Drops.SQL.Database.Index.column_count(index)
      2

      iex> index = Drops.SQL.Database.Index.new("idx_users_email", ["email"], true, :btree)
      iex> Drops.SQL.Database.Index.column_count(index)
      1
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end

defimpl Drops.Relation.Schema.Field.Inference, for: Drops.SQL.Database.Index do
  @moduledoc """
  Implementation of Drops.Relation.Schema.Inference protocol for Index structs.

  Converts database Index structs to Drops.Relation.Schema.Index structs.
  """

  alias Drops.Relation.Schema

  def to_schema_field(%Drops.SQL.Database.Index{} = index, _table) do
    field_names = Enum.map(index.columns, &String.to_atom/1)

    Schema.Index.from_names(
      index.name,
      field_names,
      index.unique,
      index.type
    )
  end
end
