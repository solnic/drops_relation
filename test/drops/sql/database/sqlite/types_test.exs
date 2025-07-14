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
      string_field = find_column(table, :string_field)
      assert string_field.type == :string
      assert string_field.meta.nullable == true

      integer_field = find_column(table, :integer_field)
      assert integer_field.type == :integer
      assert integer_field.meta.nullable == true

      text_field = find_column(table, :text_field)
      # SQLite TEXT maps to :string
      assert text_field.type == :string
      assert text_field.meta.nullable == true

      binary_field = find_column(table, :binary_field)
      assert binary_field.type == :binary
      assert binary_field.meta.nullable == true

      column = table[:array_with_string_member_field]
      assert column.type == :string
      assert column.meta.default == nil

      column = table[:array_with_string_member_and_default]
      assert column.type == :string
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

      # Test timestamps (SQLite stores as TEXT)
      inserted_at = find_column(table, :inserted_at)
      # SQLite stores datetime as TEXT
      assert inserted_at.type == :string
      assert inserted_at.meta.nullable == false

      updated_at = find_column(table, :updated_at)
      # SQLite stores datetime as TEXT
      assert updated_at.type == :string
      assert updated_at.meta.nullable == false
    end
  end

  describe "custom types table" do
    @tag relations: [:custom_types], adapter: :sqlite
    test "introspects SQLite-specific types correctly", %{repo: repo} do
      {:ok, table} = Database.table("custom_types", repo)

      assert table.name == :custom_types
      assert table.adapter == :sqlite

      # SQLite-specific type mappings
      blob_field = find_column(table, :blob_field)
      # BLOB maps to :binary
      assert blob_field.type == :binary

      real_field = find_column(table, :real_field)
      # REAL maps to :float
      assert real_field.type == :float

      numeric_field = find_column(table, :numeric_field)
      # NUMERIC maps to :decimal
      assert numeric_field.type == :decimal

      # SQLite boolean (stored as INTEGER)
      boolean_field = find_column(table, :boolean_field)
      # SQLite stores boolean as INTEGER
      assert boolean_field.type == :integer

      boolean_false_default = find_column(table, :boolean_false_default)
      # SQLite stores boolean as INTEGER
      assert boolean_false_default.type == :integer
      # SQLite stores true as boolean value
      assert boolean_false_default.meta.default === false

      boolean_true_default = find_column(table, :boolean_true_default)
      # SQLite stores boolean as INTEGER
      assert boolean_true_default.type == :integer
      # SQLite stores true as boolean value
      assert boolean_true_default.meta.default === true

      # SQLite date/time types (stored as TEXT)
      date_field = find_column(table, :date_field)
      # SQLite stores date as TEXT
      assert date_field.type == :string

      time_field = find_column(table, :time_field)
      # SQLite stores time as TEXT
      assert time_field.type == :string

      datetime_field = find_column(table, :datetime_field)
      # SQLite stores datetime as TEXT
      assert datetime_field.type == :string

      # SQLite with various defaults
      integer_zero_default = find_column(table, :integer_zero_default)
      assert integer_zero_default.type == :integer
      assert integer_zero_default.meta.default == 0

      integer_one_default = find_column(table, :integer_one_default)
      assert integer_one_default.type == :integer
      assert integer_one_default.meta.default == 1

      text_with_default = find_column(table, :text_with_default)
      assert text_with_default.type == :string
      assert text_with_default.meta.default == "sqlite_default"

      # SQLite precision types
      decimal_field = find_column(table, :decimal_field)
      assert decimal_field.type == :decimal

      float_field = find_column(table, :float_field)
      # SQLite FLOAT maps to NUMERIC/decimal
      assert float_field.type == :decimal

      double_field = find_column(table, :double_field)
      # SQLite DOUBLE maps to NUMERIC/decimal
      assert double_field.type == :decimal

      # SQLite string variations (all stored as TEXT)
      varchar_field = find_column(table, :varchar_field)
      assert varchar_field.type == :string

      char_field = find_column(table, :char_field)
      assert char_field.type == :string

      clob_field = find_column(table, :clob_field)
      assert clob_field.type == :string

      # SQLite JSON (stored as TEXT)
      json_field = find_column(table, :json_field)
      # SQLite stores JSON as TEXT
      assert json_field.type == :string

      # SQLite constraints
      required_text = find_column(table, :required_text)
      assert required_text.type == :string
      assert required_text.meta.nullable == false

      optional_text = find_column(table, :optional_text)
      assert optional_text.type == :string
      assert optional_text.meta.nullable == true

      # SQLite score field (check constraint would be in table creation SQL)
      score_field = find_column(table, :score_field)
      assert score_field.type == :integer
    end
  end

  defp find_column(table, column_name) do
    table[column_name] ||
      raise "Column #{column_name} not found in table #{table.name}"
  end
end
