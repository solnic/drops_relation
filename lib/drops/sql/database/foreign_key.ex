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
end
