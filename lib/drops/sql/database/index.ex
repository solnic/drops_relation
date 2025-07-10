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
  def unique?(%__MODULE__{meta: %{unique: unique}}), do: unique

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
  def partial?(%__MODULE__{meta: %{where_clause: where_clause}}), do: not is_nil(where_clause)

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
    Schema.Index.from_names(
      index.name,
      index.columns,
      index.meta.unique,
      index.meta.type
    )
  end
end
