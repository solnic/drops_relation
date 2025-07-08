defmodule Ecto.Relation.SQL.Introspector.Database do
  @moduledoc """
  Behavior for database-specific introspection operations.

  This behavior defines the interface that database adapters must implement
  to support schema introspection in Ecto.Relation. Each database adapter
  provides its own implementation of these callbacks to handle database-specific
  queries and return structured database metadata.

  ## Callbacks

  - `introspect_table/2` - Extract complete table metadata from the database
  - `introspect_table_columns/2` - Get column metadata for a table
  - `introspect_table_foreign_keys/2` - Get foreign key metadata for a table
  - `introspect_table_indexes/2` - Get index metadata for a table
  - `db_type_to_ecto_type/2` - Convert database types to Ecto types
  - `index_type_to_atom/1` - Convert database index types to atoms

  ## Implementations

  - `Ecto.Relation.SQL.Introspector.Database.SQLite` - SQLite adapter
  - `Ecto.Relation.SQL.Introspector.Database.Postgres` - PostgreSQL adapter

  ## Example

      defmodule MyCustomAdapter do
        @behaviour Ecto.Relation.SQL.Introspector.Database

        @impl true
        def introspect_table(repo, table_name) do
          # Return complete Table struct with all metadata
        end

        @impl true
        def introspect_table_columns(repo, table_name) do
          # Return list of Column structs
        end

        @impl true
        def introspect_table_foreign_keys(repo, table_name) do
          # Return list of ForeignKey structs
        end

        @impl true
        def introspect_table_indexes(repo, table_name) do
          # Return list of Index structs
        end

        @impl true
        def db_type_to_ecto_type(db_type, field_name) do
          # Custom type mapping for your database
        end

        @impl true
        def index_type_to_atom(index_type) do
          # Custom index type mapping for your database
        end
      end
  """

  alias Ecto.Relation.SQL.Database.{Table, Column, ForeignKey, Index}

  @doc """
  Introspects a complete table with all metadata.

  This is the main introspection function that returns a complete Table struct
  with columns, primary key, foreign keys, and indexes.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  Returns `{:ok, %Table{}}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> MyAdapter.introspect_table(MyRepo, "users")
      {:ok, %Ecto.Relation.SQL.Database.Table{name: "users", columns: [...], ...}}
  """
  @callback introspect_table(module(), String.t()) :: {:ok, Table.t()} | {:error, term()}

  @doc """
  Introspects database table columns.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  Returns `{:ok, [%Column{}]}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> MyAdapter.introspect_table_columns(MyRepo, "users")
      {:ok, [%Ecto.Relation.SQL.Database.Column{name: "id", type: "integer", ...}]}
  """
  @callback introspect_table_columns(module(), String.t()) ::
              {:ok, [Column.t()]} | {:error, term()}

  @doc """
  Introspects database table foreign keys.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  Returns `{:ok, [%ForeignKey{}]}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> MyAdapter.introspect_table_foreign_keys(MyRepo, "posts")
      {:ok, [%Ecto.Relation.SQL.Database.ForeignKey{columns: ["user_id"], referenced_table: "users", ...}]}
  """
  @callback introspect_table_foreign_keys(module(), String.t()) ::
              {:ok, [ForeignKey.t()]} | {:error, term()}

  @doc """
  Introspects database table indexes.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  Returns `{:ok, [%Index{}]}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> MyAdapter.introspect_table_indexes(MyRepo, "users")
      {:ok, [%Ecto.Relation.SQL.Database.Index{name: "idx_users_email", columns: ["email"], ...}]}
  """
  @callback introspect_table_indexes(module(), String.t()) ::
              {:ok, [Index.t()]} | {:error, term()}

  @doc """
  Converts database types to Ecto types.

  ## Parameters

  - `db_type` - The database type as a string
  - `field_name` - The field name (used for foreign key detection)

  ## Returns

  An Ecto type atom.

  ## Examples

      iex> MyAdapter.db_type_to_ecto_type("INTEGER", "user_id")
      :id
      iex> MyAdapter.db_type_to_ecto_type("TEXT", "name")
      :string
  """
  @callback db_type_to_ecto_type(String.t(), String.t()) :: atom()

  @doc """
  Converts database-specific index types to atoms.

  ## Parameters

  - `index_type` - The database-specific index type as a string

  ## Returns

  An atom representing the index type, or `nil` if unknown.

  ## Examples

      iex> MyAdapter.index_type_to_atom("btree")
      :btree
      iex> MyAdapter.index_type_to_atom("unknown_type")
      nil
  """
  @callback index_type_to_atom(String.t()) :: atom() | nil
end
