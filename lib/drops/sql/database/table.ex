defmodule Drops.SQL.Database.Table do
  @moduledoc """
  Represents a complete database table with all its metadata.

  This struct stores comprehensive information about a database table including
  its name, columns, primary key, foreign keys, and indices extracted from
  database introspection.

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

  @doc """
  Creates a Table struct from introspection data.

  This is a convenience function for creating tables from the raw data
  returned by database introspection.

  ## Parameters

  - `name` - The table name
  - `adapter` - The database adapter (:postgres, :sqlite, etc.)
  - `columns` - List of Column structs
  - `foreign_keys` - List of ForeignKey structs (optional)
  - `indices` - List of Index structs (optional)

  ## Examples

      iex> alias Drops.SQL.Database.Column
      iex> columns = [Column.new("id", :integer, false, nil, true)]
      iex> Drops.SQL.Database.Table.from_introspection("users", :postgres, columns)
      %Drops.SQL.Database.Table{
        name: "users",
        adapter: :postgres,
        columns: [%Drops.SQL.Database.Column{name: "id", ...}],
        primary_key: %Drops.SQL.Database.PrimaryKey{columns: ["id"]},
        foreign_keys: [],
        indices: []
      }
  """
  @spec from_introspection(String.t(), adapter(), [Column.t()], [ForeignKey.t()], [
          Index.t()
        ]) :: t()
  def from_introspection(name, adapter, columns, foreign_keys \\ [], indices \\ []) do
    primary_key = PrimaryKey.from_columns(columns)

    new(name, adapter, columns, primary_key, foreign_keys, indices)
  end

  @doc """
  Gets a column by name.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [
      ...>   Column.new("id", :integer, false, nil, true),
      ...>   Column.new("email", "varchar(255)", true, nil, false)
      ...> ]
      iex> table = Table.from_introspection("users", columns)
      iex> column = Table.get_column(table, "email")
      iex> column.name
      "email"

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [Column.new("id", :integer, false, nil, true)]
      iex> table = Table.from_introspection("users", columns)
      iex> Table.get_column(table, "nonexistent")
      nil
  """
  @spec get_column(t(), String.t()) :: Column.t() | nil
  def get_column(%__MODULE__{columns: columns}, column_name)
      when is_binary(column_name) do
    Enum.find(columns, &(&1.name == column_name))
  end

  @doc """
  Gets all column names.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [
      ...>   Column.new("id", :integer, false, nil, true),
      ...>   Column.new("email", "varchar(255)", true, nil, false)
      ...> ]
      iex> table = Table.from_introspection("users", columns)
      iex> Table.column_names(table)
      ["id", "email"]
  """
  @spec column_names(t()) :: [String.t()]
  def column_names(%__MODULE__{columns: columns}) do
    Enum.map(columns, & &1.name)
  end

  @doc """
  Gets primary key column names.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [
      ...>   Column.new("id", :integer, false, nil, true),
      ...>   Column.new("email", "varchar(255)", true, nil, false)
      ...> ]
      iex> table = Table.from_introspection("users", columns)
      iex> Table.primary_key_column_names(table)
      ["id"]
  """
  @spec primary_key_column_names(t()) :: [String.t()]
  def primary_key_column_names(%__MODULE__{primary_key: primary_key}) do
    PrimaryKey.column_names(primary_key)
  end

  @doc """
  Gets foreign key column names.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, ForeignKey, Table}
      iex> columns = [
      ...>   Column.new("id", :integer, false, nil, true),
      ...>   Column.new("user_id", :integer, false, nil, false)
      ...> ]
      iex> fks = [ForeignKey.simple("user_id", "users")]
      iex> table = Table.from_introspection("posts", columns, fks)
      iex> Table.foreign_key_column_names(table)
      ["user_id"]
  """
  @spec foreign_key_column_names(t()) :: [String.t()]
  def foreign_key_column_names(%__MODULE__{foreign_keys: foreign_keys}) do
    foreign_keys
    |> Enum.flat_map(&ForeignKey.column_names/1)
    |> Enum.uniq()
  end

  @doc """
  Checks if a column is part of the primary key.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [Column.new("id", :integer, false, nil, true)]
      iex> table = Table.from_introspection("users", columns)
      iex> Table.primary_key_column?(table, "id")
      true

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [Column.new("id", :integer, false, nil, true)]
      iex> table = Table.from_introspection("users", columns)
      iex> Table.primary_key_column?(table, "email")
      false
  """
  @spec primary_key_column?(t(), String.t()) :: boolean()
  def primary_key_column?(%__MODULE__{primary_key: primary_key}, column_name) do
    PrimaryKey.includes_column?(primary_key, column_name)
  end

  @doc """
  Checks if a column is part of any foreign key.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, ForeignKey, Table}
      iex> columns = [Column.new("user_id", :integer, false, nil, false)]
      iex> fks = [ForeignKey.simple("user_id", "users")]
      iex> table = Table.from_introspection("posts", columns, fks)
      iex> Table.foreign_key_column?(table, "user_id")
      true

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [Column.new("title", "varchar(255)", true, nil, false)]
      iex> table = Table.from_introspection("posts", columns)
      iex> Table.foreign_key_column?(table, "title")
      false
  """
  @spec foreign_key_column?(t(), String.t()) :: boolean()
  def foreign_key_column?(%__MODULE__{foreign_keys: foreign_keys}, column_name) do
    Enum.any?(foreign_keys, &ForeignKey.includes_column?(&1, column_name))
  end

  @doc """
  Gets the foreign key that includes a specific column.

  ## Examples

      iex> alias Drops.SQL.Database.{Column, ForeignKey, Table}
      iex> columns = [Column.new("user_id", :integer, false, nil, false)]
      iex> fks = [ForeignKey.simple("user_id", "users")]
      iex> table = Table.from_introspection("posts", columns, fks)
      iex> fk = Table.get_foreign_key_for_column(table, "user_id")
      iex> fk.referenced_table
      "users"

      iex> alias Drops.SQL.Database.{Column, Table}
      iex> columns = [Column.new("title", "varchar(255)", true, nil, false)]
      iex> table = Table.from_introspection("posts", columns)
      iex> Table.get_foreign_key_for_column(table, "title")
      nil
  """
  @spec get_foreign_key_for_column(t(), String.t()) :: ForeignKey.t() | nil
  def get_foreign_key_for_column(%__MODULE__{foreign_keys: foreign_keys}, column_name) do
    Enum.find(foreign_keys, &ForeignKey.includes_column?(&1, column_name))
  end
end
