defmodule Drops.Database.Postgres.TypesTest do
  use Test.RelationCase, async: false

  alias Drops.SQL.Database

  describe "common types table" do
    @tag relations: [:common_types], adapter: :postgres
    test "introspects common types correctly", %{repo: repo} do
      {:ok, table} = Database.table("common_types", repo)

      assert table.name == :common_types
      assert table.adapter == :postgres

      assert_column(table, :string_field, :string, nullable: true)
      assert_column(table, :integer_field, :integer, nullable: true)
      # PostgreSQL TEXT maps to :string
      assert_column(table, :text_field, :string, nullable: true)

      assert_column(table, :binary_field, :binary, nullable: true)

      assert_column(table, :array_with_string_member_field, {:array, :string}, default: nil)
      assert_column(table, :array_with_string_member_and_default, {:array, :string}, default: [])

      assert_column(table, :array_with_jsonb_member_field, {:array, :jsonb}, default: nil)
      assert_column(table, :array_with_jsonb_member_and_default, {:array, :jsonb}, default: [])

      assert_column(table, :jsonb_with_empty_map_default, :jsonb, default: %{})
      assert_column(table, :jsonb_with_empty_list_default, :jsonb, default: [])

      # Test types with defaults
      assert_column(table, :string_with_default, :string, default: "default_value")
      assert_column(table, :integer_with_default, :integer, default: 42)

      # Test nullable vs non-nullable
      assert_column(table, :required_string, :string, nullable: false)
      assert_column(table, :optional_string, :string, nullable: true)

      # Test timestamps
      assert_column(table, :inserted_at, :naive_datetime, nullable: false)
      assert_column(table, :updated_at, :naive_datetime, nullable: false)
    end
  end

  describe "custom types table" do
    @tag relations: [:custom_types], adapter: :postgres
    test "introspects PostgreSQL-specific types correctly", %{repo: repo} do
      {:ok, table} = Database.table("custom_types", repo)

      assert table.name == :custom_types
      assert table.adapter == :postgres

      # PostgreSQL-specific integer types
      assert_column(table, :smallint_field, :integer)
      assert_column(table, :bigint_field, :integer)
      assert_column(table, :serial_field, :integer, default: :auto_increment)
      assert_column(table, :bigserial_field, :integer, default: :auto_increment)

      # PostgreSQL-specific floating point types
      assert_column(table, :real_field, :float)
      assert_column(table, :double_precision_field, :float)
      assert_column(table, :numeric_field, :decimal)

      # PostgreSQL-specific string types
      assert_column(table, :varchar_field, :string)
      assert_column(table, :char_field, :string)
      assert_column(table, :citext_field, :string, case_sensitive: false)

      # PostgreSQL-specific date/time types
      assert_column(table, :date_field, :date)
      assert_column(table, :time_field, :time)
      assert_column(table, :timestamp_field, :naive_datetime)
      assert_column(table, :timestamptz_field, :utc_datetime)

      # PostgreSQL-specific types
      assert_column(table, :uuid_field, :uuid)
      assert_column(table, :json_field, :json)
      assert_column(table, :jsonb_field, :jsonb)
      assert_column(table, :bytea_field, :binary)

      # PostgreSQL boolean (native boolean type)
      assert_column(table, :boolean_field, :boolean, nullable: true)
      assert_column(table, :boolean_with_default, :boolean, default: true)

      # PostgreSQL array types
      assert_column(table, :integer_array, {:array, :integer})
      assert_column(table, :text_array, {:array, :string})
      assert_column(table, :boolean_array, {:array, :boolean})
      assert_column(table, :uuid_array, {:array, :uuid})

      # PostgreSQL enums
      assert_column(table, :enum_field, {:enum, ["red", "green", "blue"]})
      assert_column(table, :enum_with_default, {:enum, ["red", "green", "blue"]}, default: "blue")

      # PostgreSQL network types (mapped to string)
      assert_column(table, :inet_field, :string)
      assert_column(table, :cidr_field, :string)
      assert_column(table, :macaddr_field, :string)

      # PostgreSQL geometric types (mapped to string)
      assert_column(table, :point_field, :string)
      assert_column(table, :line_field, :string)
      assert_column(table, :polygon_field, :string)

      # PostgreSQL with specific defaults
      assert_column(table, :varchar_with_default, :string, default: "pg_default")
      assert_column(table, :boolean_false_default, :boolean, default: false)
      assert_column(table, :numeric_with_precision, :decimal)

      # Default as a function
      assert_column(table, :function_default, :uuid, default: nil, function_default: true)
    end
  end
end
