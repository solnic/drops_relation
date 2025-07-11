defmodule Drops.SQL.Introspection do
  @moduledoc """
  High-level database introspection utilities for extracting complete schema metadata.

  This module provides a unified interface for database introspection that works
  across different SQL database adapters. It serves as the main entry point for
  extracting complete table metadata including columns, constraints, indices,
  and relationships.

  ## Purpose

  While Ecto schemas provide application-level structure, this module extracts
  the actual database schema as it exists in the database. This is useful for:

  - Schema generation and synchronization
  - Database documentation and analysis
  - Migration validation
  - Reverse engineering existing databases

  ## Architecture

  The module uses a behavior-based approach where database-specific adapters
  implement the introspection logic. The main `introspect_table/2` function
  automatically detects the database adapter and delegates to the appropriate
  implementation.

  ## Supported Databases

  - **PostgreSQL** - via `Drops.SQL.Postgres`
  - **SQLite** - via `Drops.SQL.Sqlite`

  ## Usage

      # Introspect a complete table
      {:ok, table} = Drops.SQL.Introspection.introspect_table("users", MyApp.Repo)

      # The returned table contains all metadata
      %Drops.SQL.Database.Table{
        name: :users,
        adapter: :postgres,
        columns: [
          %Drops.SQL.Database.Column{name: :id, type: :integer, ...},
          %Drops.SQL.Database.Column{name: :email, type: :string, ...}
        ],
        primary_key: %Drops.SQL.Database.PrimaryKey{fields: [:id], ...},
        foreign_keys: [...],
        indices: [...]
      }

  ## Error Handling

  The function returns `{:error, reason}` for various failure conditions:

  - Table does not exist
  - Database connection issues
  - Unsupported database adapter
  - Permission issues

  ## Relationship to Other Modules

  This module is a convenience wrapper around `Drops.SQL.Database.table/2`.
  For more control over the introspection process, you can use the Database
  module directly or work with specific adapter modules.
  """

  alias Drops.SQL
  alias Drops.SQL.Database.Table

  @doc """
  Introspects a complete table with all metadata.

  This is the main introspection function that returns a complete Table struct
  with columns, primary key, foreign keys, and indices. It automatically detects
  the database adapter from the repository and delegates to the appropriate
  adapter implementation.

  ## Parameters

  - `table_name` - The name of the table to introspect (string)
  - `repo` - The Ecto repository module

  ## Returns

  - `{:ok, Table.t()}` - Successfully introspected table with complete metadata
  - `{:error, term()}` - Error during introspection

  ## Examples

      # Introspect a users table
      {:ok, table} = Drops.SQL.Introspection.introspect_table("users", MyApp.Repo)

      # Access the table metadata
      table.name          # :users
      table.adapter       # :postgres (or :sqlite)
      table.columns       # [%Column{...}, ...]
      table.primary_key   # %PrimaryKey{...}
      table.foreign_keys  # [%ForeignKey{...}, ...]
      table.indices       # [%Index{...}, ...]

  ## Error Cases

      # Table doesn't exist
      {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}}

      # Unsupported adapter
      {:error, {:unsupported_adapter, SomeAdapter}}

      # Connection issues
      {:error, %DBConnection.ConnectionError{...}}

  ## Implementation Note

  This function is a convenience wrapper around `Drops.SQL.Database.table/2`.
  It provides the same functionality with a more descriptive name for the
  introspection use case.
  """
  @spec introspect_table(String.t(), module()) :: {:ok, Table.t()} | {:error, term()}
  def introspect_table(table_name, repo) when is_binary(table_name) do
    case get_database_adapter(repo) do
      {:ok, adapter_module} ->
        adapter_module.table(table_name, repo)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Determines the appropriate database adapter module from an Ecto repository.
  # Returns {:ok, adapter_module} for supported adapters or {:error, {:unsupported_adapter, adapter}} for unsupported ones.
  # Supported: Ecto.Adapters.SQLite3 → Drops.SQL.Sqlite, Ecto.Adapters.Postgres → Drops.SQL.Postgres
  @spec get_database_adapter(module()) ::
          {:ok, module()} | {:error, {:unsupported_adapter, module()}}
  defp get_database_adapter(repo) do
    case repo.__adapter__() do
      Ecto.Adapters.SQLite3 ->
        {:ok, SQL.Sqlite}

      Ecto.Adapters.Postgres ->
        {:ok, SQL.Postgres}

      adapter ->
        {:error, {:unsupported_adapter, adapter}}
    end
  end
end
