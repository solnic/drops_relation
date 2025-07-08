defmodule Ecto.Relation.SQL.Introspector do
  @moduledoc """
  Database introspection utilities for extracting schema metadata.

  This module provides functions to introspect database-level information
  that is not available through Ecto schemas, such as index information.

  Uses a behavior-based approach to support multiple database adapters.
  """

  alias Ecto.Relation.Schema.Indices
  alias Ecto.Relation.SQL.Introspector.Database
  alias Ecto.Relation.SQL.Database.Table

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

      iex> Ecto.Relation.SQL.Introspector.introspect_table(MyRepo, "users")
      {:ok, %Ecto.Relation.SQL.Database.Table{name: "users", columns: [...], ...}}
  """
  @spec introspect_table(module(), String.t()) :: {:ok, Table.t()} | {:error, term()}
  def introspect_table(repo, table_name) when is_binary(table_name) do
    # Get the appropriate database adapter and delegate
    case get_database_adapter(repo) do
      {:ok, adapter_module} ->
        adapter_module.introspect_table(repo, table_name)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts index information for a table from the database.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  Returns `{:ok, %Indices{}}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Ecto.Relation.SQL.Introspector.get_table_indices(MyRepo, "users")
      {:ok, %Ecto.Relation.Schema.Indices{indices: [...]}}
  """
  @spec get_table_indices(module(), String.t()) :: {:ok, Indices.t()} | {:error, term()}
  def get_table_indices(repo, table_name) when is_binary(table_name) do
    # Get the appropriate database adapter and delegate
    case get_database_adapter(repo) do
      {:ok, adapter_module} ->
        adapter_module.get_table_indices(repo, table_name)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Introspects database table columns using database-specific queries.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The name of the table to introspect

  ## Returns

  A list of column metadata maps with keys:
  - `:name` - Column name as string
  - `:type` - Database type as string
  - `:not_null` - Boolean indicating if column is NOT NULL
  - `:primary_key` - Boolean indicating if column is part of primary key

  ## Examples

      iex> columns = Ecto.Relation.SQL.Introspector.introspect_table_columns(MyRepo, "users")
      iex> hd(columns)
      %{name: "id", type: "INTEGER", not_null: true, primary_key: true}
  """
  @spec introspect_table_columns(module(), String.t()) :: [map()]
  def introspect_table_columns(repo, table_name) do
    case get_database_adapter(repo) do
      {:ok, adapter_module} ->
        # Try the new method first
        case adapter_module.introspect_table_columns(repo, table_name) do
          {:ok, columns} ->
            # Convert Column structs back to maps for backward compatibility
            Enum.map(columns, fn column ->
              %{
                name: column.name,
                type: column.type,
                not_null: not column.nullable,
                primary_key: column.primary_key,
                default: column.default,
                nullable: column.nullable,
                check_constraints: column.check_constraints
              }
            end)

          {:error, reason} ->
            raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
    end
  end

  @doc """
  Converts database types to Ecto types using database-specific logic.

  ## Parameters

  - `repo` - The Ecto repository module
  - `db_type` - The database type as a string
  - `field_name` - The field name (used for foreign key detection)

  ## Returns

  An Ecto type atom.
  """
  @spec db_type_to_ecto_type(module(), String.t(), String.t()) :: atom()
  def db_type_to_ecto_type(repo, db_type, field_name) do
    case get_database_adapter(repo) do
      {:ok, adapter_module} ->
        adapter_module.db_type_to_ecto_type(db_type, field_name)

      {:error, _reason} ->
        # Fallback to a basic type mapping
        :string
    end
  end

  # Private helper functions

  defp get_database_adapter(repo) do
    case repo.__adapter__() do
      Ecto.Adapters.SQLite3 ->
        {:ok, Database.SQLite}

      Ecto.Adapters.Postgres ->
        {:ok, Database.Postgres}

      adapter ->
        {:error, {:unsupported_adapter, adapter}}
    end
  end
end
