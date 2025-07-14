defmodule Drops.SQL.Compilers.Postgres do
  @moduledoc """
  PostgreSQL-specific compiler for processing database introspection ASTs.

  This module implements the `Drops.SQL.Compiler` behavior to provide PostgreSQL-specific
  type mapping and AST processing. It converts PostgreSQL database types to Ecto types
  and handles PostgreSQL's rich type system including arrays, custom types, and advanced
  data types.
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

  @float_types ["real", "float4", "double precision", "float8"]

  @decimal_types ["numeric", "decimal", "money"]

  @time_types ["time", "time without time zone", "time with time zone", "timetz"]

  @naive_datetime_types ["timestamp without time zone", "timestamp"]

  @utc_datetime_types ["timestamp with time zone", "timestamptz"]

  @json_types ["json", "jsonb"]

  @string_types [
    "text",
    "character",
    "character varying",
    "varchar",
    "char",
    "name",
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
  ]

  @spec visit({:type, String.t()}, map()) :: atom() | tuple() | String.t()
  def visit({:type, type}, _opts) when type in @string_types, do: :string
  def visit({:type, type}, _opts) when type in @integer_types, do: :integer
  def visit({:type, type}, _opts) when type in @float_types, do: :float
  def visit({:type, type}, _opts) when type in @decimal_types, do: :decimal
  def visit({:type, type}, _opts) when type in @time_types, do: :time
  def visit({:type, type}, _opts) when type in @naive_datetime_types, do: :naive_datetime
  def visit({:type, type}, _opts) when type in @utc_datetime_types, do: :utc_datetime
  def visit({:type, type}, _opts) when type in @json_types, do: String.to_atom(type)

  def visit({:type, "uuid"}, _opts), do: :uuid
  def visit({:type, "boolean"}, _opts), do: :boolean
  def visit({:type, "date"}, _opts), do: :date
  def visit({:type, "bytea"}, _opts), do: :binary

  def visit({:array, "jsonb[]"}, _opts), do: {:array, :jsonb}
  def visit({:array, "json[]"}, _opts), do: {:array, :json}

  def visit({:type, type}, opts) when is_binary(type) do
    if String.ends_with?(type, "[]") do
      base_type = String.slice(type, 0, String.length(type) - 2)
      base_ecto_type = visit({:type, base_type}, opts)
      {:array, base_ecto_type}
    else
      type
    end
  end

  # Visits a default value AST node for nil values. Returns nil.
  @spec visit({:default, nil}, map()) :: nil
  def visit({:default, nil}, _opts), do: nil

  # Visits a default value AST node for empty string values. Returns empty string.
  @spec visit({:default, String.t()}, map()) :: String.t()
  def visit({:default, ""}, _opts), do: ""

  # Visits a default value AST node and processes PostgreSQL default expressions.
  # Handles NULL, sequences (nextval), timestamps, quoted literals, and numeric values.
  @spec visit({:default, String.t()}, map()) :: term()
  def visit({:default, value}, _opts) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "NULL" ->
        nil

      String.starts_with?(trimmed, "'{}'") ->
        %{}

      String.starts_with?(trimmed, "'[]'") ->
        []

      String.starts_with?(trimmed, "ARRAY[]") ->
        []

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
