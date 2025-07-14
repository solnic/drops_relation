defmodule Drops.SQL.Database.TableAccessTest do
  use ExUnit.Case, async: true

  alias Drops.SQL.Database.{Table, Column}

  describe "Access behaviour" do
    setup do
      meta1 = %{nullable: false, default: nil, primary_key: true, foreign_key: false, check_constraints: []}
      meta2 = %{nullable: true, default: nil, primary_key: false, foreign_key: false, check_constraints: []}
      meta3 = %{nullable: false, default: "active", primary_key: false, foreign_key: false, check_constraints: []}

      columns = [
        Column.new(:id, :integer, meta1),
        Column.new(:email, :string, meta2),
        Column.new(:status, :string, meta3)
      ]

      table = Table.from_introspection("users", :postgres, columns)
      
      %{table: table}
    end

    test "fetch/2 returns {:ok, column} for existing columns", %{table: table} do
      assert {:ok, column} = Access.fetch(table, :id)
      assert column.name == :id
      assert column.type == :integer

      assert {:ok, column} = Access.fetch(table, :email)
      assert column.name == :email
      assert column.type == :string
    end

    test "fetch/2 returns :error for non-existing columns", %{table: table} do
      assert :error = Access.fetch(table, :nonexistent)
      assert :error = Access.fetch(table, "nonexistent")
    end

    test "bracket notation works for existing columns", %{table: table} do
      id_column = table[:id]
      assert id_column.name == :id
      assert id_column.type == :integer
      assert id_column.meta.primary_key == true

      email_column = table[:email]
      assert email_column.name == :email
      assert email_column.type == :string
      assert email_column.meta.primary_key == false

      status_column = table[:status]
      assert status_column.name == :status
      assert status_column.meta.default == "active"
    end

    test "bracket notation returns nil for non-existing columns", %{table: table} do
      assert table[:nonexistent] == nil
      assert table["nonexistent"] == nil
    end

    test "get_and_update/3 can update existing columns", %{table: table} do
      new_meta = %{nullable: false, default: "updated", primary_key: false, foreign_key: false, check_constraints: []}
      new_column = Column.new(:status, :text, new_meta)

      {old_column, updated_table} = Access.get_and_update(table, :status, fn column ->
        {column, new_column}
      end)

      assert old_column.meta.default == "active"
      assert updated_table[:status].meta.default == "updated"
      assert updated_table[:status].type == :text
    end

    test "get_and_update/3 returns {nil, table} for non-existing columns", %{table: table} do
      {result, updated_table} = Access.get_and_update(table, :nonexistent, fn column ->
        {column, column}
      end)

      assert result == nil
      assert updated_table == table
    end

    test "pop/2 removes existing columns", %{table: table} do
      {popped_column, updated_table} = Access.pop(table, :email)

      assert popped_column.name == :email
      assert popped_column.type == :string
      assert updated_table[:email] == nil
      assert length(updated_table.columns) == 2
    end

    test "pop/2 returns {nil, table} for non-existing columns", %{table: table} do
      {result, updated_table} = Access.pop(table, :nonexistent)

      assert result == nil
      assert updated_table == table
    end

    test "works with both atom and string keys for column names that are atoms", %{table: table} do
      # Column names are atoms, so atom keys work
      assert table[:id] != nil
      assert table[:email] != nil

      # String keys don't match atom column names
      assert table["id"] == nil
      assert table["email"] == nil
    end
  end

  describe "Access behaviour with string column names" do
    setup do
      meta1 = %{nullable: false, default: nil, primary_key: true, foreign_key: false, check_constraints: []}
      meta2 = %{nullable: true, default: nil, primary_key: false, foreign_key: false, check_constraints: []}

      columns = [
        Column.new("id", :integer, meta1),
        Column.new("email", :string, meta2)
      ]

      table = Table.from_introspection("users", :postgres, columns)
      
      %{table: table}
    end

    test "works with string keys when column names are strings", %{table: table} do
      # Column names are strings, so string keys work
      assert table["id"] != nil
      assert table["email"] != nil

      # Atom keys don't match string column names
      assert table[:id] == nil
      assert table[:email] == nil
    end
  end
end
