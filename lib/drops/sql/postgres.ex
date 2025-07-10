defmodule Drops.SQL.Postgres do
  @moduledoc """
  PostgreSQL implementation of the Database behavior for schema introspection.

  This module provides PostgreSQL-specific implementations for database introspection
  operations using PostgreSQL's system catalogs and information schema.

  ## Features

  - Index introspection via system catalogs
  - Column metadata extraction via information schema
  - PostgreSQL type to Ecto type conversion
  - Support for various PostgreSQL index types (btree, hash, gin, gist, brin)
  """

  use Drops.SQL.Database, adapter: :postgres

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
  def introspect_table_foreign_keys(repo, table_name) do
    # PostgreSQL foreign key introspection using information_schema
    query = """
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

    case repo.query(query, [table_name]) do
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
             [
               constraint_name,
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

  @impl true
  def introspect_table_indices(repo, table_name) do
    query = """
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

    case repo.query(query, [table_name]) do
      {:ok, %{rows: rows}} ->
        indices =
          for [index_name, column_names, is_unique, index_type] <- rows do
            field_names = Enum.map(column_names, &{:identifier, &1})
            type = {:identifier, index_type}

            meta = %{
              unique: is_unique,
              type: type
            }

            {:index, [{:identifier, index_name}, field_names, {:meta, meta}]}
          end

        {:ok, indices}

      {:error, error} ->
        {:error, error}
    end
  end

  @impl true
  def introspect_table_columns(repo, table_name) do
    query = """
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

    case repo.query(query, [table_name]) do
      {:ok, %{rows: rows}} ->
        columns =
          Enum.map(rows, fn [
                              column_name,
                              data_type,
                              nullable,
                              column_default,
                              is_primary_key
                            ] ->
            %{
              name: column_name,
              type: data_type,
              meta: %{
                nullable: nullable == "YES",
                primary_key: is_primary_key,
                default: parse_default_value(column_default),
                check_constraints: []
              }
            }
          end)

        columns = enhance_with_check_constraints(repo, table_name, columns)

        columns =
          Enum.map(columns, fn col ->
            {:column, [{:identifier, col.name}, {:type, col.type}, {:meta, col.meta}]}
          end)

        {:ok, columns}

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

  defp parse_default_value(nil), do: nil
  defp parse_default_value(""), do: nil

  defp parse_default_value(value) when is_binary(value) do
    # PostgreSQL default values can be complex expressions
    trimmed = String.trim(value)

    cond do
      trimmed == "NULL" ->
        nil

      String.starts_with?(trimmed, "nextval(") ->
        :auto_increment

      String.starts_with?(trimmed, "now()") ->
        :current_timestamp

      String.starts_with?(trimmed, "CURRENT_TIMESTAMP") ->
        :current_timestamp

      String.starts_with?(trimmed, "CURRENT_DATE") ->
        :current_date

      String.starts_with?(trimmed, "CURRENT_TIME") ->
        :current_time

      # Handle PostgreSQL type casting syntax like 'value'::type
      String.match?(trimmed, ~r/^'.*'::\w+/) ->
        # Extract the quoted value before the :: type cast
        [quoted_part | _] = String.split(trimmed, "::")
        String.trim(quoted_part, "'")

      String.match?(trimmed, ~r/^'.*'$/) ->
        String.trim(trimmed, "'")

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
    # Query PostgreSQL system catalogs for check constraints
    query = """
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

    case repo.query(query, [table_name]) do
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

  def db_type_to_ecto_type(postgres_type, field_name) do
    # Handle array types first (since we can't use String.ends_with? in guards)
    if String.ends_with?(postgres_type, "[]") do
      base_type = String.trim_trailing(postgres_type, "[]")
      {:array, db_type_to_ecto_type(base_type, field_name)}
    else
      downcased = String.downcase(postgres_type)
      convert_base_type(downcased, field_name)
    end
  end

  # Convert non-array PostgreSQL types to Ecto types
  defp convert_base_type(postgres_type, _field_name) do
    case postgres_type do
      # Integer types and aliases
      "integer" ->
        :integer

      "int" ->
        :integer

      "int4" ->
        :integer

      "bigint" ->
        :integer

      "int8" ->
        :integer

      "smallint" ->
        :integer

      "int2" ->
        :integer

      # Serial types and aliases
      "serial" ->
        :id

      "serial4" ->
        :id

      "bigserial" ->
        :id

      "serial8" ->
        :id

      "smallserial" ->
        :id

      "serial2" ->
        :id

      # Floating point types and aliases
      "real" ->
        :float

      "float4" ->
        :float

      "double precision" ->
        :float

      "float8" ->
        :float

      # Decimal types
      "numeric" ->
        :decimal

      "decimal" ->
        :decimal

      "money" ->
        :decimal

      # String types
      "text" ->
        :string

      "character varying" ->
        :string

      "varchar" ->
        :string

      "char" ->
        :string

      "character" ->
        :string

      # PostgreSQL internal name type
      "name" ->
        :string

      # Boolean type
      "boolean" ->
        :boolean

      # Binary types
      "bytea" ->
        :binary

      # Date/time types
      "date" ->
        :date

      "time" ->
        :time

      "time without time zone" ->
        :time

      "time with time zone" ->
        :time

      "timetz" ->
        :time

      "timestamp without time zone" ->
        :naive_datetime

      "timestamp" ->
        :naive_datetime

      "timestamp with time zone" ->
        :utc_datetime

      "timestamptz" ->
        :utc_datetime

      # JSON types
      "json" ->
        :map

      "jsonb" ->
        :map

      # UUID type
      "uuid" ->
        :binary_id

      # XML type
      "xml" ->
        :string

      # Network types (mapped to string for now, could be custom types later)
      "inet" ->
        :string

      "cidr" ->
        :string

      "macaddr" ->
        :string

      # Geometric types (mapped to string for now, could be custom types later)
      "point" ->
        :string

      "line" ->
        :string

      "lseg" ->
        :string

      "box" ->
        :string

      "path" ->
        :string

      "polygon" ->
        :string

      "circle" ->
        :string

      # Interval type (could be custom type later)
      "interval" ->
        :string

      # PostgreSQL Range Types - map to EctoRange types if available
      "int4range" ->
        range_type_for(:int4range)

      "int8range" ->
        range_type_for(:int8range)

      "numrange" ->
        range_type_for(:numrange)

      "tsrange" ->
        range_type_for(:tsrange)

      "tstzrange" ->
        range_type_for(:tstzrange)

      "daterange" ->
        range_type_for(:daterange)

      # Handle complex types that need pattern matching
      type ->
        cond do
          String.starts_with?(type, "character varying(") ->
            :string

          String.starts_with?(type, "varchar(") ->
            :string

          String.starts_with?(type, "character(") ->
            :string

          String.starts_with?(type, "char(") ->
            :string

          String.starts_with?(type, "numeric(") ->
            :decimal

          String.starts_with?(type, "decimal(") ->
            :decimal

          # Fallback for unknown range types (custom ranges not in our list)
          String.ends_with?(type, "range") ->
            :string

          true ->
            :string
        end
    end
  end

  # Helper function to conditionally return EctoRange types if available
  defp range_type_for(range_type) do
    if Code.ensure_loaded?(EctoRange) do
      case range_type do
        :int4range -> EctoRange.IntegerRange
        :int8range -> EctoRange.IntegerRange
        :numrange -> EctoRange.DecimalRange
        :tsrange -> EctoRange.NaiveDateTimeRange
        :tstzrange -> EctoRange.DateTimeRange
        :daterange -> EctoRange.DateRange
        _ -> :string
      end
    else
      :string
    end
  end
end
