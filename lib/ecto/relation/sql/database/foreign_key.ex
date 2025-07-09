defmodule Ecto.Relation.SQL.Database.ForeignKey do
  @moduledoc """
  Represents a foreign key constraint in a database table.

  This struct stores information about foreign key relationships, supporting both
  single-column and composite foreign keys. The columns attribute contains
  the names of columns in the current table that reference another table.

  ## Examples

      # Simple foreign key
      %Ecto.Relation.SQL.Database.ForeignKey{
        name: "fk_posts_user_id",
        columns: ["user_id"],
        referenced_table: "users",
        referenced_columns: ["id"],
        on_delete: :delete_all,
        on_update: :restrict
      }

      # Composite foreign key
      %Ecto.Relation.SQL.Database.ForeignKey{
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

  @type t :: %__MODULE__{
          name: String.t() | nil,
          columns: [String.t()],
          referenced_table: String.t(),
          referenced_columns: [String.t()],
          on_delete: action(),
          on_update: action()
        }

  defstruct [
    :name,
    :columns,
    :referenced_table,
    :referenced_columns,
    :on_delete,
    :on_update
  ]

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

      iex> Ecto.Relation.SQL.Database.ForeignKey.new(
      ...>   "fk_posts_user_id",
      ...>   ["user_id"],
      ...>   "users",
      ...>   ["id"],
      ...>   :delete_all,
      ...>   :restrict
      ...> )
      %Ecto.Relation.SQL.Database.ForeignKey{
        name: "fk_posts_user_id",
        columns: ["user_id"],
        referenced_table: "users",
        referenced_columns: ["id"],
        on_delete: :delete_all,
        on_update: :restrict
      }
  """
  @spec new(String.t() | nil, [String.t()], String.t(), [String.t()], action(), action()) ::
          t()
  def new(
        name,
        columns,
        referenced_table,
        referenced_columns,
        on_delete \\ nil,
        on_update \\ nil
      ) do
    %__MODULE__{
      name: name,
      columns: columns,
      referenced_table: referenced_table,
      referenced_columns: referenced_columns,
      on_delete: on_delete,
      on_update: on_update
    }
  end

  @doc """
  Creates a simple single-column foreign key.

  This is a convenience function for the most common case of a single-column
  foreign key referencing a primary key.

  ## Parameters

  - `column` - The column name in the current table
  - `referenced_table` - The name of the referenced table
  - `referenced_column` - The column name in the referenced table (defaults to "id")

  ## Examples

      iex> Ecto.Relation.SQL.Database.ForeignKey.simple("user_id", "users")
      %Ecto.Relation.SQL.Database.ForeignKey{
        name: nil,
        columns: ["user_id"],
        referenced_table: "users",
        referenced_columns: ["id"],
        on_delete: nil,
        on_update: nil
      }

      iex> Ecto.Relation.SQL.Database.ForeignKey.simple("organization_id", "organizations", "uuid")
      %Ecto.Relation.SQL.Database.ForeignKey{
        name: nil,
        columns: ["organization_id"],
        referenced_table: "organizations",
        referenced_columns: ["uuid"],
        on_delete: nil,
        on_update: nil
      }
  """
  @spec simple(String.t(), String.t(), String.t()) :: t()
  def simple(column, referenced_table, referenced_column \\ "id") do
    new(nil, [column], referenced_table, [referenced_column])
  end

  @doc """
  Checks if the foreign key is composite (has multiple columns).

  ## Examples

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Ecto.Relation.SQL.Database.ForeignKey.composite?(fk)
      false

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Ecto.Relation.SQL.Database.ForeignKey.composite?(fk)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{columns: columns}) do
    length(columns) > 1
  end

  @doc """
  Gets the column names that form the foreign key.

  ## Examples

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Ecto.Relation.SQL.Database.ForeignKey.column_names(fk)
      ["user_id", "role_id"]
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}), do: columns

  @doc """
  Gets the referenced column names.

  ## Examples

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Ecto.Relation.SQL.Database.ForeignKey.referenced_column_names(fk)
      ["id"]
  """
  @spec referenced_column_names(t()) :: [String.t()]
  def referenced_column_names(%__MODULE__{referenced_columns: columns}), do: columns

  @doc """
  Checks if a specific column is part of the foreign key.

  ## Examples

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Ecto.Relation.SQL.Database.ForeignKey.includes_column?(fk, "user_id")
      true

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Ecto.Relation.SQL.Database.ForeignKey.includes_column?(fk, "role_id")
      false
  """
  @spec includes_column?(t(), String.t()) :: boolean()
  def includes_column?(%__MODULE__{columns: columns}, column_name)
      when is_binary(column_name) do
    column_name in columns
  end

  @doc """
  Gets the number of columns in the foreign key.

  ## Examples

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.simple("user_id", "users")
      iex> Ecto.Relation.SQL.Database.ForeignKey.column_count(fk)
      1

      iex> fk = Ecto.Relation.SQL.Database.ForeignKey.new(
      ...>   nil,
      ...>   ["user_id", "role_id"],
      ...>   "user_roles",
      ...>   ["user_id", "role_id"]
      ...> )
      iex> Ecto.Relation.SQL.Database.ForeignKey.column_count(fk)
      2
  """
  @spec column_count(t()) :: non_neg_integer()
  def column_count(%__MODULE__{columns: columns}), do: length(columns)
end

defimpl Ecto.Relation.Schema.Field.Inference, for: Ecto.Relation.SQL.Database.ForeignKey do
  @moduledoc """
  Implementation of Ecto.Relation.Schema.Inference protocol for ForeignKey structs.

  Converts database ForeignKey structs to Ecto.Relation.Schema.ForeignKey structs.
  """

  alias Ecto.Relation.Schema

  def to_schema_field(%Ecto.Relation.SQL.Database.ForeignKey{} = foreign_key, _table) do
    field_name =
      case foreign_key.columns do
        [single_column] ->
          String.to_atom(single_column)

        multiple_columns ->
          # TODO: add support for composite FKs
          String.to_atom(hd(multiple_columns))
      end

    referenced_field =
      case foreign_key.referenced_columns do
        [single_column] ->
          String.to_atom(single_column)

        multiple_columns ->
          String.to_atom(hd(multiple_columns))
      end

    Schema.ForeignKey.new(
      field_name,
      foreign_key.referenced_table,
      referenced_field
    )
  end
end
