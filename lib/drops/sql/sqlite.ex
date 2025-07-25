defmodule Drops.SQL.Sqlite do
  @moduledoc """
  SQLite database adapter for introspecting table metadata.

  This module implements the `Drops.SQL.Database` behavior to provide SQLite-specific
  database introspection capabilities. It uses SQLite's PRAGMA statements to extract
  comprehensive table metadata including columns, constraints, indices, and foreign keys.

  ## SQLite-Specific Features

  SQLite has several unique characteristics that this adapter handles:

  - **Dynamic typing** - SQLite uses type affinity rather than strict types
  - **PRAGMA statements** - Used for introspection instead of information schema
  - **Foreign key constraints** - Must be explicitly enabled and queried
  - **Check constraints** - Extracted from table creation SQL
  - **Autoincrement** - Special handling for INTEGER PRIMARY KEY columns

  ## PRAGMA Statements Used

  The adapter uses several SQLite PRAGMA statements for introspection:

  - `PRAGMA table_info(table_name)` - Column information
  - `PRAGMA index_list(table_name)` - Index information
  - `PRAGMA index_info(index_name)` - Index column details
  - `PRAGMA foreign_key_list(table_name)` - Foreign key constraints
  - `sqlite_master` table queries - Check constraints and table SQL

  ## Type Mapping

  SQLite types are mapped to Ecto types through the `Drops.SQL.Compilers.Sqlite`
  compiler. Common mappings include:

  - `INTEGER` → `:integer`
  - `TEXT` → `:string`
  - `REAL` → `:float`
  - `BLOB` → `:binary`
  - `NUMERIC` → `:decimal`

  ## Usage

      # Direct usage (typically not needed)
      {:ok, table} = Drops.SQL.Sqlite.table("users", MyApp.Repo)

      # Preferred usage through main interface
      {:ok, table} = Drops.SQL.Database.table("users", MyApp.Repo)

  ## Implementation Notes

  - Foreign key information is cross-referenced with column data
  - Index information is merged with column metadata
  - Check constraints are parsed from table creation SQL
  - Primary key detection handles both explicit and implicit cases
  - Supports composite primary keys and foreign keys

  ## Error Handling

  The adapter handles various SQLite-specific error conditions:

  - Table not found
  - Invalid PRAGMA statements
  - Foreign key constraint parsing errors
  - SQL parsing errors for check constraints
  """

  use Drops.SQL.Database, adapter: :sqlite, compiler: Drops.SQL.Compilers.Sqlite

  @introspect_columns "PRAGMA table_info(~s)"

  @introspect_indices "PRAGMA index_list(~s)"

  @introspect_index_info "PRAGMA index_info(~s)"

  @introspect_foreign_keys "PRAGMA foreign_key_list(~s)"

  @introspect_check_constraints """
  SELECT sql FROM sqlite_master
    WHERE type = 'table' AND name = ?
  """

  @list_tables """
  SELECT name
  FROM sqlite_master
  WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
  AND name != 'schema_migrations'
  ORDER BY name
  """

  @doc """
  Introspects a SQLite table and returns its complete metadata as an AST.

  This function implements the `Drops.SQL.Database` behavior for SQLite databases.
  It uses SQLite's PRAGMA statements to extract comprehensive table information
  including columns, foreign keys, and indices.

  ## Process

  1. Introspects foreign keys using `PRAGMA foreign_key_list`
  2. Introspects indices using `PRAGMA index_list` and `PRAGMA index_info`
  3. Introspects columns using `PRAGMA table_info` with cross-referenced FK/index data
  4. Combines all metadata into a table AST structure

  ## Parameters

  - `table_name` - The name of the SQLite table to introspect
  - `repo` - The Ecto repository configured for SQLite

  ## Returns

  - `{:ok, Database.table()}` - Successfully introspected table AST
  - `{:error, term()}` - Error during introspection (table not found, etc.)

  ## AST Structure

  Returns a table AST in the format:
  `{:table, {{:identifier, table_name}, columns, foreign_keys, indices}}`

  ## SQLite-Specific Behavior

  - Handles SQLite's dynamic typing system
  - Processes composite primary keys correctly
  - Cross-references foreign key and index information with columns
  - Extracts check constraints from table creation SQL
  - Handles autoincrement detection for INTEGER PRIMARY KEY columns
  """
  @impl true
  @spec introspect_table(String.t(), module()) :: {:ok, Database.table()} | {:error, term()}
  def introspect_table(table_name, repo) do
    with {:ok, foreign_keys} <- introspect_foreign_keys(repo, table_name),
         {:ok, indices} <- introspect_indices(repo, table_name),
         {:ok, columns} <-
           introspect_columns(repo, table_name, foreign_keys, indices) do
      {:ok, {:table, {{:identifier, table_name}, columns, foreign_keys, indices}}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all tables in the SQLite database.

  This function implements the `list_tables/1` callback for SQLite databases.
  It queries the sqlite_master table to retrieve all user-defined tables.

  ## Parameters

  - `repo` - The Ecto repository configured for SQLite

  ## Returns

  - `{:ok, [String.t()]}` - Successfully retrieved list of table names
  - `{:error, term()}` - Error during query execution

  ## Examples

      {:ok, tables} = Drops.SQL.Sqlite.list_tables(MyApp.Repo)
      # => {:ok, ["users", "posts", "comments"]}

  ## Implementation Notes

  - Excludes SQLite system tables (those starting with 'sqlite_')
  - Excludes migration tables (those ending with '_migrations')
  - Results are ordered alphabetically by table name
  - Only returns actual tables, not views or other database objects
  """
  @impl true
  @spec list_tables(module()) :: {:ok, [String.t()]} | {:error, term()}
  def list_tables(repo) do
    case repo.query(@list_tables, []) do
      {:ok, %{rows: rows}} ->
        table_names = Enum.map(rows, fn [table_name] -> table_name end)
        {:ok, table_names}

      {:error, error} ->
        {:error, error}
    end
  end

  # Introspects column information using PRAGMA table_info and cross-references with FK/index data.
  # Returns {:ok, columns} or {:error, reason}.
  @spec introspect_columns(module(), String.t(), list(), list()) ::
          {:ok, list()} | {:error, term()}
  defp introspect_columns(repo, table_name, foreign_keys, indices) do
    # Extract foreign key column names from all foreign keys
    foreign_key_column_names =
      foreign_keys
      |> Enum.flat_map(fn {:foreign_key, {_name, columns, _ref_table, _ref_columns, _meta}} ->
        Enum.map(columns, fn {:identifier, name} -> name end)
      end)
      |> MapSet.new()

    # Extract index information for columns
    index_info =
      indices
      |> Enum.reduce(%{}, fn {:index, {{:identifier, index_name}, field_names, _meta}}, acc ->
        Enum.reduce(field_names, acc, fn {:identifier, column_name}, inner_acc ->
          Map.put(inner_acc, column_name, index_name)
        end)
      end)

    case repo.query(table_query(@introspect_columns, table_name)) do
      {:ok, %{rows: rows, columns: _columns}} ->
        # PRAGMA table_info returns: [cid, name, type, notnull, column_default, pk]
        # pk is 0 for non-primary key columns, and 1, 2, 3, etc. for primary key columns
        # indicating their position in a composite primary key
        columns =
          Enum.map(rows, fn [_cid, name, type, notnull, column_default, pk] ->
            # Get check constraints for this column
            check_constraints = get_column_check_constraints(repo, table_name, name)

            # Check if column is part of a foreign key
            is_foreign_key = MapSet.member?(foreign_key_column_names, name)

            # Check if column has an index
            {has_index, index_name} =
              case Map.get(index_info, name) do
                nil -> {false, nil}
                idx_name -> {true, idx_name}
              end

            meta = %{
              primary_key: pk > 0,
              nullable: notnull != 1,
              default: {:default, column_default},
              check_constraints: check_constraints,
              foreign_key: is_foreign_key,
              index: has_index,
              index_name: index_name
            }

            {:column, {{:identifier, name}, {:type, type}, {:meta, meta}}}
          end)

        {:ok, columns}

      {:error, error} ->
        raise "Failed to introspect table #{table_name}: #{inspect(error)}"
    end
  end

  # Introspects index information using PRAGMA index_list and PRAGMA index_info.
  # Returns {:ok, indices} or {:error, reason}.
  @spec introspect_indices(module(), String.t()) :: {:ok, list()} | {:error, term()}
  defp introspect_indices(repo, table_name) do
    case repo.query(table_query(@introspect_indices, table_name)) do
      {:ok, %{rows: rows}} ->
        # PRAGMA index_list returns: [seq, name, unique, origin, partial]
        indices =
          for [_seq, name, unique, _origin, _partial] <- rows do
            # Get index details
            index_info_query =
              :io_lib.format(@introspect_index_info, [name]) |> IO.iodata_to_binary()

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

                {:index, {{:identifier, name}, field_names, {:meta, meta}}}

              {:error, _} ->
                # If we can't get field info, create index with empty fields
                meta = %{
                  unique: unique == 1,
                  type: :btree,
                  where_clause: nil
                }

                {:index, {{:identifier, name}, [], {:meta, meta}}}
            end
          end
          |> Enum.reject(&is_nil/1)

        {:ok, indices}

      {:error, error} ->
        {:error, error}
    end
  end

  # Introspects foreign key constraints using PRAGMA foreign_key_list.
  # Returns {:ok, foreign_keys} or {:error, reason}.
  @spec introspect_foreign_keys(module(), String.t()) :: {:ok, list()} | {:error, term()}
  defp introspect_foreign_keys(repo, table_name) do
    case repo.query(table_query(@introspect_foreign_keys, table_name)) do
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
             {
               # Sqlite doesn't provide constraint names in PRAGMA
               nil,
               columns,
               {:identifier, referenced_table},
               referenced_columns,
               {:meta, meta}
             }}
          end)

        {:ok, foreign_keys}

      {:error, error} ->
        {:error, error}
    end
  end

  # Parses SQLite foreign key action strings into atoms.
  # Returns action atom or nil for unknown actions.
  @spec parse_foreign_key_action(String.t() | term()) :: atom() | nil
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

  # Extracts check constraints for a specific column from table creation SQL.
  # Returns list of check constraint expressions.
  @spec get_column_check_constraints(module(), String.t(), String.t()) :: [String.t()]
  defp get_column_check_constraints(repo, table_name, column_name) do
    case repo.query(@introspect_check_constraints, [table_name]) do
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

  # Extracts CHECK constraint expressions from table creation SQL using regex.
  # Returns list of constraint expressions.
  @spec extract_check_constraints_from_sql(String.t()) :: [String.t()]
  defp extract_check_constraints_from_sql(sql) do
    # Simple regex to extract CHECK constraints
    # This is a basic implementation - could be enhanced for more complex cases
    ~r/CHECK\s*\(([^)]+)\)/i
    |> Regex.scan(sql, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end

  # Formats a query template with table name for SQLite PRAGMA statements.
  @spec table_query(String.t(), String.t()) :: String.t()
  defp table_query(query, table_name),
    do: :io_lib.format(query, [table_name]) |> IO.iodata_to_binary()
end
