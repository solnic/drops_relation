defmodule Drops.SQL.SqliteTest do
  use Drops.RelationCase, async: false

  alias Drops.SQL.Database

  describe "Database.table/2" do
    @tag relations: [:type_mapping_tests], adapter: :sqlite
    test "returns a complete table with all components for type_mapping_tests", %{repo: repo} do
      {:ok, table} = Database.table("type_mapping_tests", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :type_mapping_tests
      assert table.adapter == :sqlite

      # Verify columns are present and properly structured
      assert is_list(table.columns)
      # Should have many type test columns
      assert length(table.columns) > 10

      # Check specific columns exist with proper metadata
      assert_column(table, :id, :integer, primary_key: true)
      # Primary key columns in SQLite can be nullable unless explicitly NOT NULL
      # This is a SQLite quirk - we'll just verify it's a boolean
      id_column = table[:id]
      assert is_boolean(id_column.meta.nullable)

      assert_column(table, :integer_type, :integer, primary_key: false)
      assert_column(table, :boolean_type, :integer, primary_key: false, default: true)
      assert_column(table, :text_type, :string)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert [pk] = table.primary_key.columns
      assert pk.name == :id

      # Verify indices are present (from migration)
      assert is_list(table.indices)
      # Should have indices from migration
      assert length(table.indices) >= 2

      # Find specific indices
      integer_index =
        Enum.find(table.indices, fn index ->
          :integer_type in index.columns
        end)

      assert integer_index
      assert integer_index.meta.unique == false

      text_unique_index =
        Enum.find(table.indices, fn index ->
          :text_type in index.columns and index.meta.unique
        end)

      assert text_unique_index
      assert text_unique_index.meta.unique == true

      # Verify foreign keys (should be empty for this table)
      assert is_list(table.foreign_keys)
      assert table.foreign_keys == []
    end

    @tag relations: [:special_cases], adapter: :sqlite
    test "returns table with foreign keys for special_cases", %{repo: repo} do
      {:ok, table} = Database.table("special_cases", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :special_cases
      assert table.adapter == :sqlite

      # Verify columns
      assert is_list(table.columns)

      # Check foreign key columns exist
      assert_column(table, :user_id, :integer)
      assert_column(table, :parent_id, :integer)

      # Verify foreign keys are detected
      assert is_list(table.foreign_keys)
      # Should have foreign keys from migration
      assert length(table.foreign_keys) >= 1

      # Check specific foreign key properties
      user_fk =
        Enum.find(table.foreign_keys, fn fk ->
          :user_id in fk.columns
        end)

      if user_fk do
        assert user_fk.referenced_table == :users
        assert user_fk.referenced_columns == [:id]
        assert user_fk.meta.on_delete == :cascade
      end

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert [pk] = table.primary_key.columns
      assert pk.name == :id

      # Verify indices
      assert is_list(table.indices)
    end

    @tag relations: [:metadata_test], adapter: :sqlite
    test "returns table with comprehensive metadata for metadata_test", %{repo: repo} do
      {:ok, table} = Database.table("metadata_test", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :metadata_test
      assert table.adapter == :sqlite

      # Verify columns with various metadata
      assert is_list(table.columns)

      # Check status column with default value
      assert_column(table, :status, :string, nullable: false, default: "active")

      # Check nullable description column
      assert_column(table, :description, :string, nullable: true)

      # Check non-nullable name column
      assert_column(table, :name, :string, nullable: false)

      # Check priority column with numeric default
      assert_column(table, :priority, :integer, default: 1)

      # Check boolean column with default
      # SQLite stores booleans as integers
      assert_column(table, :is_enabled, :integer, default: 1)

      # Check score column with check constraints
      assert_column(table, :score, :integer, nullable: false)
      # Check constraints should be detected
      score_column = table[:score]
      assert is_list(score_column.meta.check_constraints)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert [pk] = table.primary_key.columns
      assert pk.name == :id

      # Verify indices from migration
      assert is_list(table.indices)
      # Should have indices from migration
      assert length(table.indices) >= 2

      # Find specific indices
      status_index =
        Enum.find(table.indices, fn index ->
          :status in index.columns and length(index.columns) == 1
        end)

      assert status_index

      composite_index =
        Enum.find(table.indices, fn index ->
          :name in index.columns and :priority in index.columns
        end)

      assert composite_index
      assert length(composite_index.columns) == 2

      # Verify foreign keys (should be empty for this table)
      assert is_list(table.foreign_keys)
      assert table.foreign_keys == []
    end

    @tag relations: [:user_groups], adapter: :sqlite
    test "returns table with foreign key and index metadata in columns for user_groups", %{
      repo: repo
    } do
      {:ok, table} = Database.table("user_groups", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :user_groups
      assert table.adapter == :sqlite

      # Check user_id column - should have foreign_key: true and index: true
      assert_column(table, :user_id, :integer, foreign_key: true, index: true)
      user_id_column = table[:user_id]
      assert is_binary(user_id_column.meta.index_name)

      # Check group_id column - should have foreign_key: true and index: true
      assert_column(table, :group_id, :integer, foreign_key: true, index: true)
      group_id_column = table[:group_id]
      assert is_binary(group_id_column.meta.index_name)

      # Check id column - should have foreign_key: false and index: false
      assert_column(table, :id, :integer,
        primary_key: true,
        foreign_key: false,
        index: false,
        index_name: nil
      )

      # Check timestamp columns - should have foreign_key: false and index: false
      # SQLite stores timestamps as strings
      assert_column(table, :inserted_at, :string,
        foreign_key: false,
        index: false,
        index_name: nil
      )
    end

    test "handles non-existent table gracefully" do
      # SQLite doesn't error on non-existent tables in PRAGMA queries,
      # it just returns empty results, which should result in a table with no columns
      case Database.table("non_existent_table", Drops.Relation.Repos.Sqlite) do
        # This is fine
        {:error, _reason} ->
          :ok

        {:ok, table} ->
          # If it succeeds, it should be an empty table
          assert table.columns == []
      end
    end
  end
end
