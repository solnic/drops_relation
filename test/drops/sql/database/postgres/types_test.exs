defmodule Drops.Database.Postgres.TypesTest do
  use Drops.RelationCase, async: false

  alias Drops.SQL.Database

  describe "common types table" do
    @tag relations: [:common_types], adapter: :postgres
    test "introspects common types correctly", %{repo: repo} do
      {:ok, table} = Database.table("common_types", repo)

      assert table.name == :common_types
      assert table.adapter == :postgres

      # Test basic types
      string_field = find_column(table, :string_field)
      assert string_field.type == :string
      assert string_field.meta.nullable == true

      integer_field = find_column(table, :integer_field)
      assert integer_field.type == :integer
      assert integer_field.meta.nullable == true

      text_field = find_column(table, :text_field)
      # PostgreSQL TEXT maps to :string
      assert text_field.type == :string
      assert text_field.meta.nullable == true

      binary_field = find_column(table, :binary_field)
      assert binary_field.type == :binary
      assert binary_field.meta.nullable == true

      column = table[:array_with_string_member_field]
      assert column.type == {:array, :string}
      assert column.meta.default == nil

      column = table[:array_with_string_member_and_default]
      assert column.type == {:array, :string}
      assert column.meta.default == []

      jsonb_with_empty_map_default = find_column(table, :jsonb_with_empty_map_default)
      assert jsonb_with_empty_map_default.type == :jsonb
      assert jsonb_with_empty_map_default.meta.default == %{}

      jsonb_with_empty_list_default = find_column(table, :jsonb_with_empty_list_default)
      assert jsonb_with_empty_list_default.type == :jsonb
      assert jsonb_with_empty_list_default.meta.default == []

      # Test types with defaults
      string_with_default = find_column(table, :string_with_default)
      assert string_with_default.type == :string
      assert string_with_default.meta.default == "default_value"

      integer_with_default = find_column(table, :integer_with_default)
      assert integer_with_default.type == :integer
      assert integer_with_default.meta.default == 42

      # Test nullable vs non-nullable
      required_string = find_column(table, :required_string)
      assert required_string.type == :string
      assert required_string.meta.nullable == false

      optional_string = find_column(table, :optional_string)
      assert optional_string.type == :string
      assert optional_string.meta.nullable == true

      # Test timestamps
      inserted_at = find_column(table, :inserted_at)
      assert inserted_at.type == :naive_datetime
      assert inserted_at.meta.nullable == false

      updated_at = find_column(table, :updated_at)
      assert updated_at.type == :naive_datetime
      assert updated_at.meta.nullable == false
    end
  end

  describe "custom types table" do
    @tag relations: [:custom_types], adapter: :postgres
    test "introspects PostgreSQL-specific types correctly", %{repo: repo} do
      {:ok, table} = Database.table("custom_types", repo)

      assert table.name == :custom_types
      assert table.adapter == :postgres

      # PostgreSQL-specific integer types
      smallint_field = find_column(table, :smallint_field)
      # smallint maps to :integer in Ecto
      assert smallint_field.type == :integer

      bigint_field = find_column(table, :bigint_field)
      # bigint maps to :integer in Ecto
      assert bigint_field.type == :integer

      serial_field = find_column(table, :serial_field)
      assert serial_field.type == :integer
      # Serial fields have auto_increment
      assert serial_field.meta.default == :auto_increment

      bigserial_field = find_column(table, :bigserial_field)
      assert bigserial_field.type == :integer
      # Serial fields have auto_increment
      assert bigserial_field.meta.default == :auto_increment

      # PostgreSQL-specific floating point types
      real_field = find_column(table, :real_field)
      assert real_field.type == :float

      double_precision_field = find_column(table, :double_precision_field)
      assert double_precision_field.type == :float

      numeric_field = find_column(table, :numeric_field)
      assert numeric_field.type == :decimal

      # PostgreSQL-specific string types
      varchar_field = find_column(table, :varchar_field)
      assert varchar_field.type == :string

      char_field = find_column(table, :char_field)
      assert char_field.type == :string

      # PostgreSQL-specific date/time types
      date_field = find_column(table, :date_field)
      assert date_field.type == :date

      time_field = find_column(table, :time_field)
      assert time_field.type == :time

      timestamp_field = find_column(table, :timestamp_field)
      assert timestamp_field.type == :naive_datetime

      timestamptz_field = find_column(table, :timestamptz_field)
      assert timestamptz_field.type == :utc_datetime

      # PostgreSQL-specific types
      uuid_field = find_column(table, :uuid_field)
      assert uuid_field.type == :uuid

      json_field = find_column(table, :json_field)
      assert json_field.type == :json

      jsonb_field = find_column(table, :jsonb_field)
      assert jsonb_field.type == :jsonb

      bytea_field = find_column(table, :bytea_field)
      assert bytea_field.type == :binary

      # PostgreSQL boolean (native boolean type)
      boolean_field = find_column(table, :boolean_field)
      assert boolean_field.type == :boolean
      assert boolean_field.meta.nullable == true

      boolean_with_default = find_column(table, :boolean_with_default)
      assert boolean_with_default.type == :boolean
      assert boolean_with_default.meta.default == true

      # PostgreSQL array types
      integer_array = find_column(table, :integer_array)
      assert integer_array.type == {:array, :integer}

      text_array = find_column(table, :text_array)
      assert text_array.type == {:array, :string}

      boolean_array = find_column(table, :boolean_array)
      assert boolean_array.type == {:array, :boolean}

      uuid_array = find_column(table, :uuid_array)
      assert uuid_array.type == {:array, :uuid}

      # PostgreSQL network types (mapped to string)
      inet_field = find_column(table, :inet_field)
      assert inet_field.type == :string

      cidr_field = find_column(table, :cidr_field)
      assert cidr_field.type == :string

      macaddr_field = find_column(table, :macaddr_field)
      assert macaddr_field.type == :string

      # PostgreSQL geometric types (mapped to string)
      point_field = find_column(table, :point_field)
      assert point_field.type == :string

      line_field = find_column(table, :line_field)
      assert line_field.type == :string

      polygon_field = find_column(table, :polygon_field)
      assert polygon_field.type == :string

      # PostgreSQL with specific defaults
      varchar_with_default = find_column(table, :varchar_with_default)
      assert varchar_with_default.type == :string
      assert varchar_with_default.meta.default == "pg_default"

      boolean_false_default = find_column(table, :boolean_false_default)
      assert boolean_false_default.type == :boolean
      assert boolean_false_default.meta.default == false

      numeric_with_precision = find_column(table, :numeric_with_precision)
      assert numeric_with_precision.type == :decimal
    end
  end

  defp find_column(table, column_name) do
    Enum.find(table.columns, fn col -> col.name == column_name end) ||
      raise "Column #{column_name} not found in table #{table.name}"
  end
end
