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
  with columns, primary key, foreign keys, and indices.

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
