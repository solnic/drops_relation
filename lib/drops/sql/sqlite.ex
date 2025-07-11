defmodule Drops.SQL.Sqlite do
  @moduledoc """
  Sqlite implementation of the Database behavior for schema introspection.

  This module provides Sqlite-specific implementations for database introspection
  operations using Sqlite's PRAGMA statements and system tables.

  ## Features

  - Index introspection via PRAGMA statements
  - Column metadata extraction via PRAGMA table_info
  - Sqlite type to Ecto type conversion
  - Support for unique and composite indices
  """

  use Drops.SQL.Database, adapter: :sqlite, compiler: Drops.SQL.Compilers.Sqlite

  @impl true
  def introspect_table(table_name, repo) do
    with {:ok, columns} <- introspect_table_columns(repo, table_name),
         {:ok, foreign_keys} <- introspect_table_foreign_keys(repo, table_name),
         {:ok, indices} <- introspect_table_indices(repo, table_name) do
      {:ok, {:table, [{:identifier, table_name}, columns, foreign_keys, indices]}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def introspect_table_columns(repo, table_name) do
    query = "PRAGMA table_info(#{table_name})"

    case repo.query(query) do
      {:ok, %{rows: rows, columns: _columns}} ->
        # PRAGMA table_info returns: [cid, name, type, notnull, column_default, pk]
        # pk is 0 for non-primary key columns, and 1, 2, 3, etc. for primary key columns
        # indicating their position in a composite primary key
        columns =
          Enum.map(rows, fn [_cid, name, type, notnull, column_default, pk] ->
            # Get check constraints for this column
            check_constraints = get_column_check_constraints(repo, table_name, name)

            meta = %{
              primary_key: pk > 0,
              nullable: notnull != 1,
              default: {:default, column_default},
              check_constraints: check_constraints
            }

            {:column, [{:identifier, name}, {:type, type}, {:meta, meta}]}
          end)

        {:ok, columns}

      {:error, error} ->
        raise "Failed to introspect table #{table_name}: #{inspect(error)}"
    end
  end

  @impl true
  def introspect_table_indices(repo, table_name) do
    # Sqlite PRAGMA to get index list
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
                    {:identifier, field_name}
                  end)

                meta = %{
                  unique: unique == 1,
                  type: :btree,
                  where_clause: nil
                }

                {:index, [{:identifier, name}, field_names, {:meta, meta}]}

              {:error, _} ->
                # If we can't get field info, create index with empty fields
                meta = %{
                  unique: unique == 1,
                  type: :btree,
                  where_clause: nil
                }

                {:index, [{:identifier, name}, [], {:meta, meta}]}
            end
          end
          |> Enum.reject(&is_nil/1)

        {:ok, indices}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_column_check_constraints(repo, table_name, column_name) do
    # Sqlite stores check constraints in the CREATE TABLE statement
    # We can extract them from sqlite_master
    query = """
    SELECT sql FROM sqlite_master
    WHERE type = 'table' AND name = ?
    """

    case repo.query(query, [table_name]) do
      {:ok, %{rows: [[sql]]}} when is_binary(sql) ->
        check_constraints = extract_check_constraints_from_sql(sql)

        Enum.filter(check_constraints, fn constraint ->
          String.contains?(constraint, column_name)
        end)

      _ ->
        # If we can't get the SQL, return empty check constraints
        []
    end
  end

  @impl true
  def introspect_table_foreign_keys(repo, table_name) do
    # Sqlite foreign key introspection using PRAGMA foreign_key_list
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
            columns = Enum.map(fk_rows, &Enum.at(&1, 3)) |> Enum.map(&{:identifier, &1})

            referenced_columns =
              Enum.map(fk_rows, &Enum.at(&1, 4)) |> Enum.map(&{:identifier, &1})

            meta = %{
              on_delete: parse_foreign_key_action(on_delete),
              on_update: parse_foreign_key_action(on_update)
            }

            {:foreign_key,
             [
               # Sqlite doesn't provide constraint names in PRAGMA
               nil,
               columns,
               {:identifier, referenced_table},
               referenced_columns,
               {:meta, meta}
             ]}
          end)

        {:ok, foreign_keys}

      {:error, error} ->
        {:error, error}
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

  defp extract_check_constraints_from_sql(sql) do
    # Simple regex to extract CHECK constraints
    # This is a basic implementation - could be enhanced for more complex cases
    ~r/CHECK\s*\(([^)]+)\)/i
    |> Regex.scan(sql, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end
end
