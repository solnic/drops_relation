defmodule Drops.SQL.Compilers.Postgres do
  @moduledoc """
  PostgreSQL-specific compiler for processing database introspection ASTs.

  This module implements the `Drops.SQL.Compiler` behavior to provide PostgreSQL-specific
  type mapping and AST processing. It converts PostgreSQL database types to Ecto types
  and handles PostgreSQL's rich type system including arrays, custom types, and advanced
  data types.

  ## PostgreSQL Type System

  PostgreSQL has a sophisticated type system that this compiler maps to Ecto types:

  ### Integer Types
  - `smallint`, `int2`, `serial2`, `smallserial` → `:integer`
  - `integer`, `int`, `int4`, `serial`, `serial4` → `:integer`
  - `bigint`, `int8`, `bigserial`, `serial8` → `:integer`

  ### Floating Point Types
  - `real`, `float4` → `:float`
  - `double precision`, `float8` → `:float`

  ### Decimal Types
  - `numeric`, `decimal`, `money` → `:decimal`

  ### String Types
  - `text`, `character varying`, `varchar`, `char`, `character`, `name` → `:string`

  ### Boolean Type
  - `boolean` → `:boolean`

  ### Binary Types
  - `bytea` → `:binary`

  ### Date/Time Types
  - `date` → `:date`
  - `time`, `time without time zone`, `time with time zone`, `timetz` → `:time`
  - `timestamp`, `timestamp without time zone` → `:naive_datetime`
  - `timestamp with time zone`, `timestamptz` → `:utc_datetime`

  ### JSON Types
  - `json`, `jsonb` → `:map`

  ### UUID Type
  - `uuid` → `:uuid`

  ### Array Types
  - Any type with `[]` suffix → `{:array, base_type}`
  - Examples: `integer[]` → `{:array, :integer}`, `text[]` → `{:array, :string}`

  ### Geometric and Network Types
  - `xml`, `inet`, `cidr`, `macaddr`, `point`, `line`, `lseg`, `box`, `path`, `polygon`, `circle` → `:string`

  ## Default Value Processing

  PostgreSQL default values are processed to handle:
  - `NULL` values
  - `nextval()` sequences → `:auto_increment`
  - `now()`, `CURRENT_TIMESTAMP` → `:current_timestamp`
  - `CURRENT_DATE` → `:current_date`
  - `CURRENT_TIME` → `:current_time`
  - Quoted string literals with type casting
  - Numeric literals

  ## Usage

  This compiler is typically used automatically by the `Drops.SQL.Postgres` adapter:

      # Automatic usage through adapter
      {:ok, table} = Drops.SQL.Postgres.table("users", MyRepo)

      # Direct usage (advanced)
      ast = {:table, {{:identifier, "users"}, columns, [], []}}
      table = Drops.SQL.Compilers.Postgres.process(ast, adapter: :postgres)

  ## Implementation Notes

  - Handles PostgreSQL's internal type names (e.g., `int4` → `integer`)
  - Supports array type detection and recursive processing
  - Processes complex default value expressions
  - Maps unknown types to strings for compatibility
  - Preserves PostgreSQL-specific type information where possible
  """

  use Drops.SQL.Compiler

  @integer_types [
    "integer",
    "int",
    "int4",
    "bigint",
    "int8",
    "smallint",
    "int2",
    "serial",
    "serial4",
    "bigserial",
    "serial8",
    "smallserial",
    "serial2"
  ]

  @doc """
  Visits a type AST node and maps PostgreSQL types to Ecto types.

  This function implements PostgreSQL-specific type mapping, handling PostgreSQL's
  rich type system including arrays, custom types, and internal type names.

  ## Parameters

  - `{:type, type}` - Type AST node with PostgreSQL type name
  - `opts` - Processing options (used for recursive array processing)

  ## Returns

  Ecto type atom (`:integer`, `:string`, etc.), tuple for arrays (`{:array, base_type}`),
  or the original type if unmapped.

  ## Examples

      iex> Drops.SQL.Compilers.Postgres.visit({:type, "integer"}, [])
      :integer

      iex> Drops.SQL.Compilers.Postgres.visit({:type, "text[]"}, [])
      {:array, :string}

      iex> Drops.SQL.Compilers.Postgres.visit({:type, "uuid"}, [])
      :uuid
  """
  @spec visit({:type, String.t()}, keyword()) :: atom() | tuple() | String.t()
  def visit({:type, type}, opts) do
    case type do
      type when type in @integer_types ->
        :integer

      "uuid" ->
        :uuid

      # Floating point types
      type when type in ["real", "float4", "double precision", "float8"] ->
        :float

      # Decimal types
      type when type in ["numeric", "decimal", "money"] ->
        :decimal

      # String types
      type
      when type in ["text", "character varying", "varchar", "char", "character", "name"] ->
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

      type
      when type in ["time", "time without time zone", "time with time zone", "timetz"] ->
        :time

      type when type in ["timestamp without time zone", "timestamp"] ->
        :naive_datetime

      type when type in ["timestamp with time zone", "timestamptz"] ->
        :utc_datetime

      # JSON types
      type when type in ["json", "jsonb"] ->
        :map

      type
      when type in [
             "xml",
             "inet",
             "cidr",
             "macaddr",
             "point",
             "line",
             "lseg",
             "box",
             "path",
             "polygon",
             "circle"
           ] ->
        :string

      # Array types - handle PostgreSQL array syntax
      type when is_binary(type) ->
        if String.ends_with?(type, "[]") do
          # Extract the base type by removing the "[]" suffix
          base_type = String.slice(type, 0, String.length(type) - 2)
          # Recursively process the base type
          base_ecto_type = visit({:type, base_type}, opts)
          {:array, base_ecto_type}
        else
          # Unknown type, return as-is
          type
        end
    end
  end

  # Visits a default value AST node for nil values. Returns nil.
  @spec visit({:default, nil}, keyword()) :: nil
  def visit({:default, nil}, _opts), do: nil

  # Visits a default value AST node for empty string values. Returns empty string.
  @spec visit({:default, String.t()}, keyword()) :: String.t()
  def visit({:default, ""}, _opts), do: ""

  # Visits a default value AST node and processes PostgreSQL default expressions.
  # Handles NULL, sequences (nextval), timestamps, quoted literals, and numeric values.
  @spec visit({:default, String.t()}, keyword()) :: term()
  def visit({:default, value}, _opts) when is_binary(value) do
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

      String.match?(trimmed, ~r/^'.*'::\w+/) ->
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
end
