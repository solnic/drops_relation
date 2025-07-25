defmodule Drops.SQL.Database.TableTest do
  use Test.RelationCase, async: false

  alias Drops.SQL.Database
  alias Drops.SQL.Database.{Table, Column, PrimaryKey, ForeignKey, Index}

  describe "Table.new/6" do
    test "creates a new table struct with all components" do
      columns = [
        Column.new(:id, :integer, %{
          nullable: false,
          default: nil,
          primary_key: true,
          foreign_key: false,
          check_constraints: []
        }),
        Column.new(:name, :string, %{
          nullable: false,
          default: nil,
          primary_key: false,
          foreign_key: false,
          check_constraints: []
        }),
        Column.new(:email, :string, %{
          nullable: true,
          default: nil,
          primary_key: false,
          foreign_key: false,
          check_constraints: []
        })
      ]

      primary_key = PrimaryKey.new([:id])

      foreign_keys = [
        ForeignKey.new("fk_posts_user_id", ["user_id"], "users", ["id"], %{
          on_delete: :delete_all,
          on_update: :restrict
        })
      ]

      indices = [
        Index.new("users_email_index", [:email], %{unique: true})
      ]

      table = Table.new("users", :postgres, columns, primary_key, foreign_keys, indices)

      assert %Table{} = table
      assert table.name == "users"
      assert table.adapter == :postgres
      assert table.columns == columns
      assert table.primary_key == primary_key
      assert table.foreign_keys == foreign_keys
      assert table.indices == indices
    end

    test "creates table with minimal components" do
      columns = [
        Column.new(:id, :integer, %{
          nullable: false,
          default: nil,
          primary_key: true,
          foreign_key: false,
          check_constraints: []
        })
      ]

      primary_key = PrimaryKey.new([:id])

      table = Table.new("simple", :sqlite, columns, primary_key, [], [])

      assert %Table{} = table
      assert table.name == "simple"
      assert table.adapter == :sqlite
      assert table.columns == columns
      assert table.primary_key == primary_key
      assert table.foreign_keys == []
      assert table.indices == []
    end
  end

  describe "Access behavior" do
    setup do
      columns = [
        Column.new(:id, :integer, %{
          nullable: false,
          default: nil,
          primary_key: true,
          foreign_key: false,
          check_constraints: []
        }),
        Column.new(:name, :string, %{
          nullable: false,
          default: nil,
          primary_key: false,
          foreign_key: false,
          check_constraints: []
        }),
        Column.new(:email, :string, %{
          nullable: true,
          default: nil,
          primary_key: false,
          foreign_key: false,
          check_constraints: []
        })
      ]

      table = Table.new("users", :postgres, columns, PrimaryKey.new([:id]), [], [])
      {:ok, table: table}
    end

    test "fetch/2 with atom key", %{table: table} do
      assert {:ok, column} = Access.fetch(table, :name)
      assert column.name == :name
      assert column.type == :string

      assert :error = Access.fetch(table, :nonexistent)
    end

    test "fetch/2 with string key", %{table: table} do
      # String keys won't match atom column names in our test setup
      assert :error = Access.fetch(table, "name")
      assert :error = Access.fetch(table, "nonexistent")
    end

    test "bracket notation access", %{table: table} do
      # Test with atom key
      column = table[:name]
      assert column.name == :name
      assert column.type == :string

      # Test with string key (won't match atom column names)
      assert table["name"] == nil

      # Test with non-existent key
      assert table[:nonexistent] == nil
      assert table["nonexistent"] == nil
    end

    test "get_and_update/3 for existing column", %{table: table} do
      {old_column, updated_table} =
        Access.get_and_update(table, :name, fn column ->
          updated_meta = %{column.meta | nullable: true}
          updated_column = %{column | meta: updated_meta}
          {column, updated_column}
        end)

      assert old_column.meta.nullable == false
      updated_column = updated_table[:name]
      assert updated_column.meta.nullable == true
      assert updated_column.name == :name
      assert updated_column.type == :string
    end

    test "get_and_update/3 for non-existent column", %{table: table} do
      {nil_value, unchanged_table} =
        Access.get_and_update(table, :nonexistent, fn column ->
          {column, %{column | nullable: false}}
        end)

      assert nil_value == nil
      assert unchanged_table == table
    end

    test "get_and_update/3 with :pop", %{table: table} do
      original_count = length(table.columns)

      {popped_column, updated_table} =
        Access.get_and_update(table, :name, fn _column -> :pop end)

      assert popped_column.name == :name
      assert length(updated_table.columns) == original_count - 1
      assert updated_table[:name] == nil
    end

    test "pop/2 for existing column", %{table: table} do
      original_count = length(table.columns)

      {popped_column, updated_table} = Access.pop(table, :name)

      assert popped_column.name == :name
      assert popped_column.type == :string
      assert length(updated_table.columns) == original_count - 1
      assert updated_table[:name] == nil
    end

    test "pop/2 for non-existent column", %{table: table} do
      {nil_value, unchanged_table} = Access.pop(table, :nonexistent)

      assert nil_value == nil
      assert unchanged_table == table
    end
  end

  describe "integration with Database.table/2" do
    @tag relations: [:common_types], adapter: :sqlite
    test "Access behavior works with real table introspection", %{repo: repo} do
      {:ok, table} = Database.table("common_types", repo)

      # Test fetch with atom key
      assert {:ok, column} = Access.fetch(table, :string_field)
      assert column.name == :string_field
      assert column.type == :string

      # Test bracket notation
      column = table[:string_field]
      assert column.name == :string_field

      # Test with non-existent key
      assert table[:nonexistent] == nil
    end

    @tag relations: [:common_types], adapter: :postgres
    test "Access behavior works with PostgreSQL tables", %{repo: repo} do
      {:ok, table} = Database.table("common_types", repo)

      # Test fetch with atom key (columns are stored as atoms)
      assert {:ok, column} = Access.fetch(table, :string_field)
      assert column.name == :string_field

      # Test bracket notation with atom key
      column = table[:string_field]
      assert column.name == :string_field
    end
  end
end
