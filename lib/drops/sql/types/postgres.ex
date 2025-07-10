defmodule Drops.SQL.Types.Postgres do
  alias Drops.SQL.Database.{Column, Table}

  def to_ecto_type(%Column{} = column, %Table{adapter: :postgres} = table) do
    if String.ends_with?(column.type, "[]") do
      base_type = String.trim_trailing(column.type, "[]")
      base_column = %{column | type: base_type}
      {:array, to_ecto_type(base_column, table)}
    else
      downcased = String.downcase(column.type)
      convert_postgres_base_type(downcased, column)
    end
  end

  # Convert PostgreSQL base types with column context
  defp convert_postgres_base_type(postgres_type, column) do
    case postgres_type do
      # Integer types - use :id for primary keys, :integer for others
      type when type in ["integer", "int", "int4"] ->
        if column.primary_key, do: :id, else: :integer

      type when type in ["bigint", "int8"] ->
        if column.primary_key, do: :id, else: :integer

      type when type in ["smallint", "int2"] ->
        if column.primary_key, do: :id, else: :integer

      # Serial types are always primary keys
      type
      when type in ["serial", "serial4", "bigserial", "serial8", "smallserial", "serial2"] ->
        :id

      # UUID type - use :binary_id for consistency with Ecto conventions
      "uuid" ->
        :binary_id

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

      # Network and geometric types (mapped to string for now)
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

      # Fallback for unknown types
      _ ->
        :string
    end
  end
end
