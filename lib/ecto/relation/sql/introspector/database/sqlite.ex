defmodule Ecto.Relation.SQL.Introspector.Database.SQLite do
  @moduledoc """
  SQLite implementation of the Database behavior for schema introspection.

  This module provides SQLite-specific implementations for database introspection
  operations using SQLite's PRAGMA statements and system tables.

  ## Features

  - Index introspection via PRAGMA statements
  - Column metadata extraction via PRAGMA table_info
  - SQLite type to Ecto type conversion
  - Support for unique and composite indices
  """

  @behaviour Ecto.Relation.SQL.Introspector.Database

  alias Ecto.Relation.Schema.{Index, Indices}
  alias Ecto.Relation.SQL.Database.{Table, Column, ForeignKey}
  alias Ecto.Relation.SQL.Database.Index, as: DatabaseIndex

  # Legacy method for backward compatibility - no longer part of behavior
  def get_table_indices(repo, table_name) do
    # SQLite PRAGMA to get index list
    index_list_query = "PRAGMA index_list(#{table_name})"

    case repo.query(index_list_query) do
      {:ok, %{rows: rows}} ->
        # PRAGMA index_list returns: [seq, name, unique, origin, partial]
        indices =
          for [_seq, name, unique, _origin, _partial] <- rows do
            # Get index details
            index_info_query = "PRAGMA index_info(#{name})"

            case repo.query(index_info_query) do
              {:ok, %{rows: info_rows}} ->
                # PRAGMA index_info returns: [seqno, cid, name]
                field_names =
                  info_rows
                  # Sort by seqno
                  |> Enum.sort_by(&hd/1)
                  |> Enum.map(fn [_seqno, _cid, field_name] ->
                    String.to_atom(field_name)
                  end)

                Index.from_names(name, field_names, unique == 1, :btree)

              {:error, _} ->
                # If we can't get field info, create index with empty fields
                Index.from_names(name, [], unique == 1, :btree)
            end
          end
          |> Enum.reject(&is_nil/1)

        {:ok, Indices.new(indices)}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  defp parse_default_value(nil), do: nil
  defp parse_default_value(""), do: nil

  defp parse_default_value(value) when is_binary(value) do
    # Remove quotes if present - handle both single and double quotes properly
    trimmed =
      value
      |> String.trim()
      |> String.trim("'")
      |> String.trim("\"")

    # Try to parse as different types
    cond do
      trimmed == "NULL" ->
        nil

      trimmed == "CURRENT_TIMESTAMP" ->
        :current_timestamp

      trimmed == "CURRENT_DATE" ->
        :current_date

      trimmed == "CURRENT_TIME" ->
        :current_time

      String.match?(trimmed, ~r/^\d+$/) ->
        String.to_integer(trimmed)

      String.match?(trimmed, ~r/^\d+\.\d+$/) ->
        String.to_float(trimmed)

      String.downcase(trimmed) in ["true", "false"] ->
        String.to_existing_atom(String.downcase(trimmed))

      true ->
        trimmed
    end
  end

  defp parse_default_value(value), do: value

  defp enhance_with_check_constraints(repo, table_name, columns) do
    # SQLite stores check constraints in the CREATE TABLE statement
    # We can extract them from sqlite_master
    query = """
    SELECT sql FROM sqlite_master
    WHERE type = 'table' AND name = ?
    """

    case repo.query(query, [table_name]) do
      {:ok, %{rows: [[sql]]}} when is_binary(sql) ->
        check_constraints = extract_check_constraints_from_sql(sql)

        Enum.map(columns, fn column ->
          column_constraints =
            Enum.filter(check_constraints, fn constraint ->
              String.contains?(constraint, column.name)
            end)

          Map.put(column, :check_constraints, column_constraints)
        end)

      _ ->
        # If we can't get the SQL, just add empty check constraints
        Enum.map(columns, &Map.put(&1, :check_constraints, []))
    end
  end

  defp extract_check_constraints_from_sql(sql) do
    # Simple regex to extract CHECK constraints
    # This is a basic implementation - could be enhanced for more complex cases
    ~r/CHECK\s*\(([^)]+)\)/i
    |> Regex.scan(sql, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end

  # New callback implementations for the updated behavior

  @impl true
  def introspect_table(repo, table_name) do
    with {:ok, columns} <- introspect_table_columns(repo, table_name),
         {:ok, foreign_keys} <- introspect_table_foreign_keys(repo, table_name),
         {:ok, indexes} <- introspect_table_indexes(repo, table_name) do
      table =
        Table.from_introspection(table_name, :sqlite, columns, foreign_keys, indexes)

      {:ok, table}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def introspect_table_columns(repo, table_name) do
    # Use the existing introspect_table_columns logic but return Column structs
    try do
      column_data = introspect_table_columns_legacy(repo, table_name)
      columns = Enum.map(column_data, &Column.from_introspection/1)
      {:ok, columns}
    rescue
      error -> {:error, error}
    end
  end

  @impl true
  def introspect_table_foreign_keys(repo, table_name) do
    # SQLite foreign key introspection using PRAGMA foreign_key_list
    query = "PRAGMA foreign_key_list(#{table_name})"

    case repo.query(query) do
      {:ok, %{rows: rows}} ->
        # PRAGMA foreign_key_list returns: [id, seq, table, from, to, on_update, on_delete, match]
        foreign_keys =
          rows
          # Group by foreign key id
          |> Enum.group_by(&Enum.at(&1, 0))
          |> Enum.map(fn {_fk_id, fk_rows} ->
            # Extract information from the first row (all rows in group have same metadata)
            [
              _id,
              _seq,
              referenced_table,
              _from_column,
              _to_column,
              on_update,
              on_delete,
              _match
            ] = hd(fk_rows)

            # Collect all columns for this foreign key (for composite keys)
            columns = Enum.map(fk_rows, &Enum.at(&1, 3))
            referenced_columns = Enum.map(fk_rows, &Enum.at(&1, 4))

            ForeignKey.new(
              # SQLite doesn't provide constraint names in PRAGMA
              nil,
              columns,
              referenced_table,
              referenced_columns,
              parse_foreign_key_action(on_delete),
              parse_foreign_key_action(on_update)
            )
          end)

        {:ok, foreign_keys}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def introspect_table_indexes(repo, table_name) do
    # Use the existing get_table_indices logic but return DatabaseIndex structs
    case get_table_indices(repo, table_name) do
      {:ok, %Indices{indices: schema_indices}} ->
        database_indexes =
          Enum.map(schema_indices, fn schema_index ->
            # Extract field names from Field structs or atoms
            field_names =
              Enum.map(schema_index.fields, fn field ->
                case field do
                  %{name: name} -> to_string(name)
                  atom when is_atom(atom) -> to_string(atom)
                  string when is_binary(string) -> string
                end
              end)

            DatabaseIndex.new(
              schema_index.name,
              field_names,
              schema_index.unique,
              schema_index.type
            )
          end)

        {:ok, database_indexes}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Rename the existing method to avoid conflicts
  defp introspect_table_columns_legacy(repo, table_name) do
    # Use SQLite PRAGMA table_info to get column information
    query = "PRAGMA table_info(#{table_name})"

    case repo.query(query) do
      {:ok, %{rows: rows, columns: _columns}} ->
        # PRAGMA table_info returns: [cid, name, type, notnull, dflt_value, pk]
        # pk is 0 for non-primary key columns, and 1, 2, 3, etc. for primary key columns
        # indicating their position in a composite primary key
        columns =
          Enum.map(rows, fn [_cid, name, type, notnull, dflt_value, pk] ->
            %{
              name: name,
              type: type,
              not_null: notnull == 1,
              # Any pk > 0 indicates it's part of the primary key
              primary_key: pk > 0,
              default: parse_default_value(dflt_value),
              nullable: notnull != 1
            }
          end)

        # Enhance with check constraints
        enhance_with_check_constraints(repo, table_name, columns)

      {:error, error} ->
        raise "Failed to introspect table #{table_name}: #{inspect(error)}"
    end
  end

  defp parse_foreign_key_action(action) when is_binary(action) do
    case String.upcase(action) do
      "RESTRICT" -> :restrict
      "CASCADE" -> :cascade
      "SET NULL" -> :set_null
      "SET DEFAULT" -> :set_default
      "NO ACTION" -> :restrict
      _ -> nil
    end
  end

  defp parse_foreign_key_action(_), do: nil
end
