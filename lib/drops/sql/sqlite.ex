defmodule Drops.SQL.Sqlite do
  use Drops.SQL.Database, adapter: :sqlite, compiler: Drops.SQL.Compilers.Sqlite

  @introspect_columns "PRAGMA table_info(~s)"

  @introspect_indices "PRAGMA index_list(~s)"

  @introspect_index_info "PRAGMA index_info(~s)"

  @introspect_foreign_keys "PRAGMA foreign_key_list(~s)"

  @introspect_check_constraints """
  SELECT sql FROM sqlite_master
    WHERE type = 'table' AND name = ?
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

  defp extract_check_constraints_from_sql(sql) do
    # Simple regex to extract CHECK constraints
    # This is a basic implementation - could be enhanced for more complex cases
    ~r/CHECK\s*\(([^)]+)\)/i
    |> Regex.scan(sql, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
  end

  defp table_query(query, table_name),
    do: :io_lib.format(query, [table_name]) |> IO.iodata_to_binary()
end
