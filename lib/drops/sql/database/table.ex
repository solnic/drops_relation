defmodule Drops.SQL.Database.Table do
  @moduledoc """
  Represents a complete database table with all its metadata.

  This struct stores comprehensive information about a database table including
  its name, columns, primary key, foreign keys, and indices extracted from
  database introspection.

  ## Access Behaviour

  The Table struct implements the Access behaviour, allowing you to access columns
  by name using bracket notation:

      table[:column_name]  # Returns the Column struct or nil
      table["column_name"] # Also works with string keys

  ## Examples

      # Simple table
      %Drops.SQL.Database.Table{
        name: "users",
        columns: [
          %Drops.SQL.Database.Column{name: "id", type: :integer, primary_key: true, ...},
          %Drops.SQL.Database.Column{name: "email", type: "varchar(255)", primary_key: false, ...}
        ],
        primary_key: %Drops.SQL.Database.PrimaryKey{columns: ["id"]},
        foreign_keys: [],
        indices: [
          %Drops.SQL.Database.Index{name: "idx_users_email", columns: ["email"], unique: true, ...}
        ]
      }

      # Accessing columns
      id_column = table[:id]
      email_column = table["email"]

      # Table with foreign keys
      %Drops.SQL.Database.Table{
        name: "posts",
        columns: [...],
        primary_key: %Drops.SQL.Database.PrimaryKey{columns: ["id"]},
        foreign_keys: [
          %Drops.SQL.Database.ForeignKey{
            columns: ["user_id"],
            referenced_table: "users",
            referenced_columns: ["id"]
          }
        ],
        indices: [...]
      }
  """

  alias Drops.SQL.Database.{Column, PrimaryKey, ForeignKey, Index}

  @type adapter :: :postgres | :sqlite | :mysql | atom()

  @type t :: %__MODULE__{
          name: String.t(),
          adapter: adapter(),
          columns: [Column.t()],
          primary_key: PrimaryKey.t(),
          foreign_keys: [ForeignKey.t()],
          indices: [Index.t()]
        }

  defstruct [
    :name,
    :adapter,
    :columns,
    :primary_key,
    :foreign_keys,
    :indices
  ]

  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{columns: columns}, key) when is_atom(key) or is_binary(key) do
    case Enum.find(columns, &(&1.name == key)) do
      nil -> :error
      column -> {:ok, column}
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{columns: columns} = table, key, function)
      when is_atom(key) or is_binary(key) do
    case Enum.find_index(columns, &(&1.name == key)) do
      nil ->
        {nil, table}

      index ->
        current_column = Enum.at(columns, index)

        case function.(current_column) do
          {get_value, new_column} ->
            new_columns = List.replace_at(columns, index, new_column)
            {get_value, %{table | columns: new_columns}}

          :pop ->
            new_columns = List.delete_at(columns, index)
            {current_column, %{table | columns: new_columns}}
        end
    end
  end

  @impl Access
  def pop(%__MODULE__{columns: columns} = table, key) when is_atom(key) or is_binary(key) do
    case Enum.find_index(columns, &(&1.name == key)) do
      nil ->
        {nil, table}

      index ->
        column = Enum.at(columns, index)
        new_columns = List.delete_at(columns, index)
        {column, %{table | columns: new_columns}}
    end
  end

  @doc """
  Creates a new Table struct.

  ## Parameters

  - `name` - The table name
  - `adapter` - The database adapter (:postgres, :sqlite, etc.)
  - `columns` - List of Column structs
  - `primary_key` - PrimaryKey struct
  - `foreign_keys` - List of ForeignKey structs
  - `indices` - List of Index structs

  ## Examples

      iex> alias Drops.SQL.Database.{Column, PrimaryKey, ForeignKey, Index}
      iex> columns = [Column.new("id", :integer, false, nil, true)]
      iex> pk = PrimaryKey.new(["id"])
      iex> fks = []
      iex> indices = []
      iex> Drops.SQL.Database.Table.new("users", :postgres, columns, pk, fks, indices)
      %Drops.SQL.Database.Table{
        name: "users",
        adapter: :postgres,
        columns: [%Drops.SQL.Database.Column{name: "id", ...}],
        primary_key: %Drops.SQL.Database.PrimaryKey{columns: ["id"]},
        foreign_keys: [],
        indices: []
      }
  """
  @spec new(String.t(), adapter(), [Column.t()], PrimaryKey.t(), [ForeignKey.t()], [
          Index.t()
        ]) ::
          t()
  def new(name, adapter, columns, primary_key, foreign_keys, indices) do
    %__MODULE__{
      name: name,
      adapter: adapter,
      columns: columns,
      primary_key: primary_key,
      foreign_keys: foreign_keys,
      indices: indices
    }
  end
end
