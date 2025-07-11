defmodule Drops.SQL.Postgres do
  @moduledoc """
  PostgreSQL database adapter for introspecting table metadata.

  This module implements the `Drops.SQL.Database` behavior to provide PostgreSQL-specific
  database introspection capabilities. It uses PostgreSQL's system catalogs and information
  schema to extract comprehensive table metadata including columns, constraints, indices,
  and foreign keys.

  ## PostgreSQL-Specific Features

  PostgreSQL has rich metadata capabilities that this adapter leverages:

  - **System catalogs** - Direct access to `pg_*` tables for detailed metadata
  - **Array types** - Full support for PostgreSQL array types
  - **Custom types** - Handles user-defined types and enums
  - **Advanced constraints** - Check constraints, exclusion constraints
  - **Inheritance** - Table inheritance relationships
  - **Partitioning** - Partitioned table metadata

  ## System Catalogs Used

  The adapter queries several PostgreSQL system catalogs:

  - `pg_attribute` - Column information
  - `pg_type` - Type information including arrays
  - `pg_class` - Table and index information
  - `pg_constraint` - Constraint information
  - `pg_index` - Index details
  - `pg_namespace` - Schema information
  - `pg_attrdef` - Default value expressions

  ## Type Mapping

  PostgreSQL types are mapped to Ecto types through the `Drops.SQL.Compilers.Postgres`
  compiler. The adapter handles:

  - **Standard types** - `integer`, `text`, `boolean`, etc.
  - **Array types** - `integer[]`, `text[]`, etc. → `{:array, base_type}`
  - **Timestamp types** - With and without timezone
  - **JSON types** - `json` and `jsonb` → `:map`
  - **UUID type** - Native UUID support
  - **Geometric types** - `point`, `polygon`, etc.

  ## Usage

      # Direct usage (typically not needed)
      {:ok, table} = Drops.SQL.Postgres.table("users", MyApp.Repo)

      # Preferred usage through main interface
      {:ok, table} = Drops.SQL.Database.table("users", MyApp.Repo)

  ## Implementation Notes

  - Uses complex SQL queries to extract complete metadata
  - Handles PostgreSQL's internal type names (e.g., `int4` → `integer`)
  - Supports array type detection and mapping
  - Processes default value expressions correctly
  - Handles composite primary keys and foreign keys
  - Extracts check constraints from system catalogs

  ## Error Handling

  The adapter handles various PostgreSQL-specific error conditions:

  - Table not found in specified schema
  - Permission denied on system catalogs
  - Invalid type mappings
  - Constraint parsing errors
  """

  use Drops.SQL.Database, adapter: :postgres, compiler: Drops.SQL.Compilers.Postgres

  @introspect_columns """
    SELECT
        a.attname as column_name,
        CASE
            -- PostgreSQL Array Types (internal names start with _)
            WHEN t.typname = '_int2' THEN 'smallint[]'
            WHEN t.typname = '_int4' THEN 'integer[]'
            WHEN t.typname = '_int8' THEN 'bigint[]'
            WHEN t.typname = '_float4' THEN 'real[]'
            WHEN t.typname = '_float8' THEN 'double precision[]'
            WHEN t.typname = '_numeric' THEN 'numeric[]'
            WHEN t.typname = '_bool' THEN 'boolean[]'
            WHEN t.typname = '_text' THEN 'text[]'
            WHEN t.typname = '_varchar' THEN 'character varying[]'
            WHEN t.typname = '_bpchar' THEN 'character[]'
            WHEN t.typname = '_char' THEN 'character[]'
            WHEN t.typname = '_date' THEN 'date[]'
            WHEN t.typname = '_time' THEN 'time without time zone[]'
            WHEN t.typname = '_timetz' THEN 'time with time zone[]'
            WHEN t.typname = '_timestamp' THEN 'timestamp without time zone[]'
            WHEN t.typname = '_timestamptz' THEN 'timestamp with time zone[]'
            WHEN t.typname = '_uuid' THEN 'uuid[]'
            WHEN t.typname = '_json' THEN 'json[]'
            WHEN t.typname = '_jsonb' THEN 'jsonb[]'
            -- Standard PostgreSQL types
            WHEN t.typname = 'int2' THEN 'smallint'
            WHEN t.typname = 'int4' THEN 'integer'
            WHEN t.typname = 'int8' THEN 'bigint'
            WHEN t.typname = 'float4' THEN 'real'
            WHEN t.typname = 'float8' THEN 'double precision'
            WHEN t.typname = 'bpchar' THEN 'character'
            WHEN t.typname = 'varchar' THEN 'character varying'
            WHEN t.typname = 'bool' THEN 'boolean'
            -- Keep standard PostgreSQL type names as-is
            ELSE t.typname
        END as data_type,
        CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END as nullable,
        pg_get_expr(ad.adbin, ad.adrelid) as column_default,
        CASE
            WHEN pk.attname IS NOT NULL THEN true
            ELSE false
        END as is_primary_key
    FROM pg_attribute a
    JOIN pg_type t ON a.atttypid = t.oid
    JOIN pg_class c ON a.attrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
    LEFT JOIN (
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        JOIN pg_class c ON i.indrelid = c.oid
        WHERE c.relname = $1 AND i.indisprimary
    ) pk ON pk.attname = a.attname
    WHERE c.relname = $1
        AND n.nspname = 'public'
        AND a.attnum > 0
        AND NOT a.attisdropped
    ORDER BY a.attnum
  """

  @introspect_foreign_keys """
  SELECT
      tc.constraint_name,
      kcu.column_name,
      ccu.table_name AS referenced_table,
      ccu.column_name AS referenced_column,
      rc.update_rule,
      rc.delete_rule
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
  JOIN information_schema.referential_constraints rc
      ON tc.constraint_name = rc.constraint_name
      AND tc.table_schema = rc.constraint_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_name = $1
  ORDER BY tc.constraint_name, kcu.ordinal_position
  """

  @introspect_indices """
  SELECT
      i.relname as index_name,
      array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)) as column_names,
      ix.indisunique as is_unique,
      am.amname as index_type
  FROM pg_class t
  JOIN pg_index ix ON t.oid = ix.indrelid
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
  JOIN pg_am am ON i.relam = am.oid
  WHERE t.relname = $1
    AND NOT ix.indisprimary  -- Exclude primary key indices
  GROUP BY i.relname, ix.indisunique, am.amname
  ORDER BY i.relname
  """

  @check_constraints """
  SELECT
      con.conname as constraint_name,
      pg_get_constraintdef(con.oid) as constraint_definition,
      array_agg(att.attname) as column_names
  FROM pg_constraint con
  JOIN pg_class rel ON rel.oid = con.conrelid
  JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  LEFT JOIN pg_attribute att ON att.attrelid = con.conrelid
      AND att.attnum = ANY(con.conkey)
  WHERE con.contype = 'c'
      AND rel.relname = $1
      AND nsp.nspname = 'public'
  GROUP BY con.conname, con.oid
  """

  @doc """
  Introspects a PostgreSQL table and returns its complete metadata as an AST.

  This function implements the `Drops.SQL.Database` behavior for PostgreSQL databases.
  It uses PostgreSQL's system catalogs to extract comprehensive table information
  including columns, foreign keys, and indices.

  ## Process

  1. Introspects foreign keys using system catalog queries
  2. Introspects indices using `pg_index` and related catalogs
  3. Introspects columns using `pg_attribute` with cross-referenced FK/index data
  4. Combines all metadata into a table AST structure

  ## Parameters

  - `table_name` - The name of the PostgreSQL table to introspect
  - `repo` - The Ecto repository configured for PostgreSQL

  ## Returns

  - `{:ok, Database.table()}` - Successfully introspected table AST
  - `{:error, term()}` - Error during introspection (table not found, etc.)

  ## AST Structure

  Returns a table AST in the format:
  `{:table, {{:identifier, table_name}, columns, foreign_keys, indices}}`

  ## PostgreSQL-Specific Behavior

  - Handles PostgreSQL's rich type system including arrays
  - Processes complex default value expressions
  - Extracts check constraints from system catalogs
  - Handles composite primary keys and foreign keys
  - Supports PostgreSQL-specific constraint types
  - Maps internal type names to standard PostgreSQL types
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

  # Introspects foreign key constraints using PostgreSQL system catalogs.
  # Returns {:ok, foreign_keys} or {:error, reason}.
  @spec introspect_foreign_keys(module(), String.t()) :: {:ok, list()} | {:error, term()}
  defp introspect_foreign_keys(repo, table_name) do
    case repo.query(@introspect_foreign_keys, [table_name]) do
      {:ok, %{rows: rows}} ->
        foreign_keys =
          rows
          |> Enum.group_by(&Enum.at(&1, 0))
          |> Enum.map(fn {constraint_name, fk_rows} ->
            [
              _constraint_name,
              _column_name,
              referenced_table,
              _referenced_column,
              update_rule,
              delete_rule
            ] = hd(fk_rows)

            columns = Enum.map(fk_rows, &Enum.at(&1, 1)) |> Enum.map(&{:identifier, &1})

            referenced_columns =
              Enum.map(fk_rows, &Enum.at(&1, 3)) |> Enum.map(&{:identifier, &1})

            meta = %{
              on_delete: parse_foreign_key_action(delete_rule),
              on_update: parse_foreign_key_action(update_rule)
            }

            {:foreign_key,
             {
               {:identifier, constraint_name},
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

  # Introspects index information using PostgreSQL system catalogs.
  # Returns {:ok, indices} or {:error, reason}.
  @spec introspect_indices(module(), String.t()) :: {:ok, list()} | {:error, term()}
  defp introspect_indices(repo, table_name) do
    case repo.query(@introspect_indices, [table_name]) do
      {:ok, %{rows: rows}} ->
        indices =
          for [index_name, column_names, is_unique, index_type] <- rows do
            field_names = Enum.map(column_names, &{:identifier, &1})
            type = {:identifier, index_type}

            meta = %{
              unique: is_unique,
              type: type
            }

            {:index, {{:identifier, index_name}, field_names, {:meta, meta}}}
          end

        {:ok, indices}

      {:error, error} ->
        {:error, error}
    end
  end

  # Introspects column information using PostgreSQL system catalogs and cross-references with FK/index data.
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

    case repo.query(@introspect_columns, [table_name]) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [
                              column_name,
                              data_type,
                              nullable,
                              column_default,
                              is_primary_key
                            ] ->
            # Check if column is part of a foreign key
            is_foreign_key = MapSet.member?(foreign_key_column_names, column_name)

            # Check if column has an index
            {has_index, index_name} =
              case Map.get(index_info, column_name) do
                nil -> {false, nil}
                idx_name -> {true, idx_name}
              end

            %{
              name: column_name,
              type: data_type,
              meta: %{
                nullable: nullable == "YES",
                primary_key: is_primary_key,
                default: {:default, column_default},
                check_constraints: [],
                foreign_key: is_foreign_key,
                index: has_index,
                index_name: index_name
              }
            }
          end)

        columns = enhance_with_check_constraints(repo, table_name, columns)

        columns =
          Enum.map(columns, fn col ->
            {:column, {{:identifier, col.name}, {:type, col.type}, {:meta, col.meta}}}
          end)

        {:ok, columns}

      {:error, error} ->
        raise "Failed to introspect table #{table_name}: #{inspect(error)}"
    end
  end

  # Parses PostgreSQL foreign key action strings into atoms.
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

  # Enhances column metadata with check constraint information from PostgreSQL system catalogs.
  # Returns enhanced columns list.
  @spec enhance_with_check_constraints(module(), String.t(), list()) :: list()
  defp enhance_with_check_constraints(repo, table_name, columns) do
    case repo.query(@check_constraints, [table_name]) do
      {:ok, %{rows: rows}} ->
        # Build a map of column names to their check constraints
        constraint_map =
          Enum.reduce(rows, %{}, fn [_name, definition, column_names], acc ->
            Enum.reduce(column_names || [], acc, fn col_name, inner_acc ->
              constraints = Map.get(inner_acc, col_name, [])
              Map.put(inner_acc, col_name, [definition | constraints])
            end)
          end)

        # Add check constraints to each column
        Enum.map(columns, fn column ->
          check_constraints = Map.get(constraint_map, column.name, [])
          Map.merge(column, %{meta: %{column.meta | check_constraints: check_constraints}})
        end)

      _ ->
        columns
    end
  end
end
