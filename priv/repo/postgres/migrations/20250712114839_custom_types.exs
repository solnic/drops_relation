defmodule Drops.Relation.Repos.Postgres.Migrations.CustomTypes20250712114839 do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION citext"

    execute "CREATE TYPE colors AS ENUM ('red', 'green', 'blue')"

    create table(:custom_types) do
      # PostgreSQL-specific integer types
      add :smallint_field, :smallint
      add :bigint_field, :bigint
      add :serial_field, :serial
      add :bigserial_field, :bigserial

      # PostgreSQL-specific floating point types
      add :real_field, :real
      add :double_precision_field, :float  # PostgreSQL double precision
      add :numeric_field, :decimal

      # PostgreSQL-specific string types
      add :varchar_field, :string  # character varying
      add :char_field, :string     # character
      add :citext_field, :citext

      # PostgreSQL-specific date/time types
      add :date_field, :date
      add :time_field, :time
      add :timestamp_field, :naive_datetime
      add :timestamptz_field, :timestamptz

      # PostgreSQL-specific types
      add :uuid_field, :binary_id
      add :json_field, :json
      add :jsonb_field, :jsonb
      add :bytea_field, :binary

      # PostgreSQL boolean (native boolean type)
      add :boolean_field, :boolean
      add :boolean_with_default, :boolean, default: true

      # PostgreSQL array types
      add :integer_array, {:array, :integer}
      add :text_array, {:array, :string}
      add :boolean_array, {:array, :boolean}
      add :uuid_array, {:array, :binary_id}

      # PostgreSQL enum type
      add :enum_field, :colors
      add :enum_with_default, :colors, default: "blue"

      # PostgreSQL network types (mapped to string for compatibility)
      add :inet_field, :string
      add :cidr_field, :string
      add :macaddr_field, :string

      # PostgreSQL geometric types (mapped to string for compatibility)
      add :point_field, :string
      add :line_field, :string
      add :polygon_field, :string

      # PostgreSQL with specific defaults
      add :varchar_with_default, :string, default: "pg_default"
      add :boolean_false_default, :boolean, default: false
      add :numeric_with_precision, :decimal, precision: 10, scale: 2

      timestamps()
    end
  end
end
