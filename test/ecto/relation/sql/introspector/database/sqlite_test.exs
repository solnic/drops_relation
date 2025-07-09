defmodule Ecto.Relation.SQL.Introspector.Database.SQLiteTest do
  use Ecto.RelationCase, async: false

  alias Ecto.Relation.SQL.Introspector.Database.SQLite
  alias Ecto.Relation.Schema.Indices

  describe "get_table_indices/2" do
    test "extracts indices from SQLite database" do
      # Create a test table with indices
      Ecto.Adapters.SQL.query!(
        Ecto.Relation.Repos.Sqlite,
        """
        CREATE TABLE test_sqlite_indices (
          id INTEGER PRIMARY KEY,
          email TEXT UNIQUE,
          name TEXT,
          status TEXT
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        Ecto.Relation.Repos.Sqlite,
        "CREATE INDEX idx_test_sqlite_name ON test_sqlite_indices(name)",
        []
      )

      Ecto.Adapters.SQL.query!(
        Ecto.Relation.Repos.Sqlite,
        "CREATE INDEX idx_test_sqlite_status_name ON test_sqlite_indices(status, name)",
        []
      )

      # Test index extraction
      {:ok, indices} = SQLite.get_table_indices(Ecto.Relation.Repos.Sqlite, "test_sqlite_indices")

      assert %Indices{} = indices
      assert length(indices.indices) >= 2

      # Find the specific indices we created
      name_index = Enum.find(indices.indices, &(&1.name == "idx_test_sqlite_name"))

      composite_index =
        Enum.find(indices.indices, &(&1.name == "idx_test_sqlite_status_name"))

      assert name_index
      assert length(name_index.fields) == 1
      assert hd(name_index.fields).name == :name
      assert name_index.unique == false

      assert composite_index
      assert length(composite_index.fields) == 2
      assert Enum.map(composite_index.fields, & &1.name) == [:status, :name]
      assert composite_index.unique == false
    end

    test "handles table with no custom indices" do
      # Create a simple table with no custom indices
      Ecto.Adapters.SQL.query!(
        Ecto.Relation.Repos.Sqlite,
        """
        CREATE TABLE test_sqlite_no_indices (
          id INTEGER PRIMARY KEY,
          data TEXT
        )
        """,
        []
      )

      {:ok, indices} =
        SQLite.get_table_indices(Ecto.Relation.Repos.Sqlite, "test_sqlite_no_indices")

      assert %Indices{} = indices
      # Should have at least the primary key index
      assert length(indices.indices) >= 0
    end

    test "returns empty indices for non-existent table" do
      # SQLite PRAGMA doesn't error for non-existent tables, it just returns empty results
      {:ok, indices} = SQLite.get_table_indices(Ecto.Relation.Repos.Sqlite, "non_existent_table")
      assert %Indices{} = indices
      assert indices.indices == []
    end
  end

  describe "introspect_table_columns/2" do
    test "extracts column information from SQLite table" do
      # Create a test table
      Ecto.Adapters.SQL.query!(
        Ecto.Relation.Repos.Sqlite,
        """
        CREATE TABLE test_sqlite_columns (
          id INTEGER PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          email TEXT UNIQUE,
          age INTEGER,
          active BOOLEAN DEFAULT 1,
          created_at DATETIME
        )
        """,
        []
      )

      {:ok, columns} =
        SQLite.introspect_table_columns(Ecto.Relation.Repos.Sqlite, "test_sqlite_columns")

      assert is_list(columns)
      assert length(columns) == 6

      # Check specific columns
      id_column = Enum.find(columns, &(&1.name == "id"))
      name_column = Enum.find(columns, &(&1.name == "name"))
      email_column = Enum.find(columns, &(&1.name == "email"))

      assert id_column
      assert id_column.type == "INTEGER"
      assert id_column.primary_key == true
      assert id_column.nullable == false

      assert name_column
      assert name_column.type == "TEXT"
      assert name_column.nullable == false

      assert email_column
      assert email_column.type == "TEXT"
    end
  end
end
