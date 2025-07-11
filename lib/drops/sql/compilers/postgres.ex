defmodule Drops.SQL.Compilers.Postgres do
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

  def visit({:default, nil}, _opts), do: nil
  def visit({:default, ""}, _opts), do: ""

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
