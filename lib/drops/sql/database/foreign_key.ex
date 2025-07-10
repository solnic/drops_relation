defmodule Drops.SQL.Database.ForeignKey do
  @moduledoc """
  Represents a foreign key constraint in a database table.

  This struct stores information about foreign key relationships, supporting both
  single-column and composite foreign keys. The columns attribute contains
  the names of columns in the current table that reference another table.

  ## Examples

      # Simple foreign key
      %Drops.SQL.Database.ForeignKey{
        name: "fk_posts_user_id",
        columns: ["user_id"],
        referenced_table: "users",
        referenced_columns: ["id"],
        on_delete: :delete_all,
        on_update: :restrict
      }

      # Composite foreign key
      %Drops.SQL.Database.ForeignKey{
        name: "fk_user_roles_composite",
        columns: ["user_id", "role_id"],
        referenced_table: "user_role_assignments",
        referenced_columns: ["user_id", "role_id"],
        on_delete: :cascade,
        on_update: :cascade
      }
  """

  @type action ::
          :restrict
          | :cascade
          | :set_null
          | :set_default
          | :delete_all
          | :nilify_all
          | nil

  @type meta :: %{
          on_delete: action(),
          on_update: action()
        }

  @type t :: %__MODULE__{
          name: String.t() | nil,
          columns: [String.t()],
          referenced_table: String.t(),
          referenced_columns: [String.t()]
        }

  defstruct [:name, :columns, :referenced_table, :referenced_columns, :meta]

  @doc """
  Creates a new ForeignKey struct.

  ## Parameters

  - `name` - The constraint name (optional)
  - `columns` - List of column names in the current table
  - `referenced_table` - The name of the referenced table
  - `referenced_columns` - List of column names in the referenced table
  - `on_delete` - Action to take when referenced row is deleted
  - `on_update` - Action to take when referenced row is updated

  ## Examples

      iex> Drops.SQL.Database.ForeignKey.new(
      ...>   "fk_posts_user_id",
      ...>   ["user_id"],
      ...>   "users",
      ...>   ["id"],
      ...>   :delete_all,
      ...>   :restrict
      ...> )
      %Drops.SQL.Database.ForeignKey{
        name: "fk_posts_user_id",
        columns: ["user_id"],
        referenced_table: "users",
        referenced_columns: ["id"],
        on_delete: :delete_all,
        on_update: :restrict
      }
  """
  @spec new(String.t(), [String.t()], String.t(), [String.t()], meta()) ::
          t()
  def new(
        name,
        columns,
        referenced_table,
        referenced_columns,
        meta
      ) do
    %__MODULE__{
      name: name,
      columns: columns,
      referenced_table: referenced_table,
      referenced_columns: referenced_columns,
      meta: meta
    }
  end

  @doc """
  Checks if the foreign key is composite (has multiple columns).

  ## Examples

      iex> fk = Drops.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Drops.SQL.Database.ForeignKey.composite?(fk)
      false

      iex> fk = Drops.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Drops.SQL.Database.ForeignKey.composite?(fk)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{columns: columns}) do
    length(columns) > 1
  end

  @doc """
  Gets the column names that form the foreign key.

  ## Examples

      iex> fk = Drops.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Drops.SQL.Database.ForeignKey.column_names(fk)
      ["user_id", "role_id"]
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}), do: columns

  @doc """
  Gets the referenced column names.

  ## Examples

      iex> fk = Drops.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Drops.SQL.Database.ForeignKey.referenced_column_names(fk)
      ["id"]
  """
  @spec referenced_column_names(t()) :: [String.t()]
  def referenced_column_names(%__MODULE__{referenced_columns: columns}), do: columns

  @doc """
  Checks if a specific column is part of the foreign key.

  ## Examples

      iex> fk = Drops.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Drops.SQL.Database.ForeignKey.includes_column?(fk, "user_id")
      true

      iex> fk = Drops.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Drops.SQL.Database.ForeignKey.includes_column?(fk, "role_id")
      false
  """
  @spec includes_column?(t(), String.t()) :: boolean()
  def includes_column?(%__MODULE__{columns: columns}, column_name) when is_atom(column_name) do
    column_name in columns
  end

  @doc """
  Gets the number of columns in the foreign key.

  ## Examples

      iex> fk = Drops.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Drops.SQL.Database.ForeignKey.column_count(fk)
      1

      iex> fk = Drops.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Drops.SQL.Database.ForeignKey.column_count(fk)
      2
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end

defimpl Drops.Relation.Schema.Field.Inference, for: Drops.SQL.Database.ForeignKey do
  @moduledoc """
  Implementation of Drops.Relation.Schema.Inference protocol for ForeignKey structs.

  Converts database ForeignKey structs to Drops.Relation.Schema.ForeignKey structs.
  """

  alias Drops.Relation.Schema

  def to_schema_field(%Drops.SQL.Database.ForeignKey{} = foreign_key, _table) do
    field_name =
      case foreign_key.columns do
        [single_column] ->
          single_column

        multiple_columns ->
          hd(multiple_columns)
      end

    referenced_field =
      case foreign_key.referenced_columns do
        [single_column] ->
          single_column

        multiple_columns ->
          hd(multiple_columns)
      end

    Schema.ForeignKey.new(field_name, foreign_key.referenced_table, referenced_field)
  end
end
