defmodule Drops.Database.Sqlite.TypesTest do
  use Drops.RelationCase, async: false

  alias Drops.SQL.Database

  describe "common types table" do
    @tag relations: [:common_types], adapter: :sqlite
    test "introspects common types correctly", %{repo: repo} do
      {:ok, table} = Database.table("common_types", repo)

      assert table.name == :common_types
      assert table.adapter == :sqlite

      # Test basic types
      assert_column(table, :string_field, :string, nullable: true)
      assert_column(table, :integer_field, :integer, nullable: true)

      # SQLite TEXT maps to :string
      assert_column(table, :text_field, :string, nullable: true)
      assert_column(table, :binary_field, :binary, nullable: true)
      assert_column(table, :array_with_string_member_field, :string, default: nil)
      assert_column(table, :array_with_string_member_and_default, :string, default: [])
      assert_column(table, :jsonb_with_empty_map_default, :jsonb, default: %{})
      assert_column(table, :jsonb_with_empty_list_default, :jsonb, default: [])

      # Test types with defaults
      assert_column(table, :string_with_default, :string, default: "default_value")
      assert_column(table, :integer_with_default, :integer, default: 42)

      # Test nullable vs non-nullable
      assert_column(table, :required_string, :string, nullable: false)
      assert_column(table, :optional_string, :string, nullable: true)

      # Test timestamps (SQLite stores as TEXT)
      # SQLite stores datetime as TEXT
      assert_column(table, :inserted_at, :string, nullable: false)
      assert_column(table, :updated_at, :string, nullable: false)
    end
  end

  describe "custom types table" do
    @tag relations: [:custom_types], adapter: :sqlite
    test "introspects SQLite-specific types correctly", %{repo: repo} do
      {:ok, table} = Database.table("custom_types", repo)

      assert table.name == :custom_types
      assert table.adapter == :sqlite

      # SQLite-specific type mappings
      # BLOB maps to :binary
      assert_column(table, :blob_field, :binary)
      # REAL maps to :float
      assert_column(table, :real_field, :float)
      # NUMERIC maps to :decimal
      assert_column(table, :numeric_field, :decimal)

      # SQLite boolean (stored as INTEGER)
      assert_column(table, :boolean_field, :integer)
      # SQLite stores boolean as INTEGER with defaults
      assert_column(table, :boolean_false_default, :integer, default: false)
      assert_column(table, :boolean_true_default, :integer, default: true)

      # SQLite date/time types (stored as TEXT)
      assert_column(table, :date_field, :string)
      assert_column(table, :time_field, :string)
      assert_column(table, :datetime_field, :string)

      # SQLite with various defaults
      assert_column(table, :integer_zero_default, :integer, default: 0)
      assert_column(table, :integer_one_default, :integer, default: 1)
      assert_column(table, :text_with_default, :string, default: "sqlite_default")

      # SQLite precision types
      assert_column(table, :decimal_field, :decimal)
      # SQLite FLOAT maps to NUMERIC/decimal
      assert_column(table, :float_field, :decimal)
      # SQLite DOUBLE maps to NUMERIC/decimal
      assert_column(table, :double_field, :decimal)

      # SQLite string variations (all stored as TEXT)
      assert_column(table, :varchar_field, :string)
      assert_column(table, :char_field, :string)

      assert_column(table, :clob_field, :string)

      # SQLite JSON (stored as TEXT)
      assert_column(table, :json_field, :string)

      # SQLite constraints
      assert_column(table, :required_text, :string, nullable: false)
      assert_column(table, :optional_text, :string, nullable: true)

      # SQLite score field (check constraint would be in table creation SQL)
      assert_column(table, :score_field, :integer)
    end
  end
end
