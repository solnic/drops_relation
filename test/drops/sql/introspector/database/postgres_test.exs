defmodule Drops.SQL.PostgresTest do
  use Drops.RelationCase, async: false

  alias Drops.SQL.Database

  describe "Database.table/2" do
    @tag relations: [:postgres_types], adapter: :postgres
    test "returns a complete table with all components for postgres_types", %{repo: repo} do
      {:ok, table} = Database.table("postgres_types", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :postgres_types
      assert table.adapter == :postgres

      # Verify columns are present and properly structured
      assert is_list(table.columns)
      # Should have many type test columns
      assert length(table.columns) > 20

      # Check specific columns exist with proper metadata
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert_column(table, :id, :integer, primary_key: true, nullable: false)

      # Check PostgreSQL-specific types
      assert_column(table, :uuid_type, :uuid)
      assert_column(table, :jsonb_type, :jsonb)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      primary_key_column_names = Enum.map(table.primary_key.columns, & &1.name)
      assert primary_key_column_names == [:id]

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

      uuid_unique_index =
        Enum.find(table.indices, fn index ->
          :uuid_type in index.columns and index.meta.unique
        end)

      assert uuid_unique_index
      assert uuid_unique_index.meta.unique == true

      # Verify foreign keys (should be empty for this table)
      assert is_list(table.foreign_keys)
      assert table.foreign_keys == []
    end

    @tag relations: [:type_mapping_tests], adapter: :postgres
    test "returns a complete table with all components for type_mapping_tests", %{repo: repo} do
      {:ok, table} = Database.table("type_mapping_tests", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :type_mapping_tests
      assert table.adapter == :postgres

      # Verify columns are present and properly structured
      assert is_list(table.columns)
      # Should have many type test columns
      assert length(table.columns) > 10

      # Check specific columns exist with proper metadata
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert_column(table, :id, :integer, primary_key: true, nullable: false)
      assert_column(table, :integer_type, :integer, primary_key: false)
      assert_column(table, :text_type, :string)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      primary_key_column_names = Enum.map(table.primary_key.columns, & &1.name)
      assert primary_key_column_names == [:id]

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

    @tag relations: [:special_cases], adapter: :postgres
    test "returns table with foreign keys for special_cases", %{repo: repo} do
      {:ok, table} = Database.table("special_cases", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :special_cases
      assert table.adapter == :postgres

      # Verify columns
      assert is_list(table.columns)

      # Check foreign key columns exist
      # PostgreSQL references are bigint
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
      primary_key_column_names = Enum.map(table.primary_key.columns, & &1.name)
      assert primary_key_column_names == [:id]

      # Verify indices
      assert is_list(table.indices)
    end

    @tag relations: [:metadata_test], adapter: :postgres
    test "returns table with comprehensive metadata for metadata_test", %{repo: repo} do
      {:ok, table} = Database.table("metadata_test", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :metadata_test
      assert table.adapter == :postgres

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
      assert_column(table, :is_enabled, :boolean, default: true)

      # Check score column with check constraints
      assert_column(table, :score, :integer, nullable: false)
      # Check constraints should be detected
      score_column = table[:score]
      assert is_list(score_column.meta.check_constraints)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      primary_key_column_names = Enum.map(table.primary_key.columns, & &1.name)
      assert primary_key_column_names == [:id]

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

    @tag relations: [:user_groups], adapter: :postgres
    test "returns table with foreign key and index metadata in columns for user_groups", %{
      repo: repo
    } do
      {:ok, table} = Database.table("user_groups", repo)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :user_groups
      assert table.adapter == :postgres

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
      assert_column(table, :inserted_at, :naive_datetime,
        foreign_key: false,
        index: false,
        index_name: nil
      )
    end

    @tag relations: [:custom_pk], adapter: :postgres
    test "correctly handles UUID primary key" do
      {:ok, table} = Database.table("custom_pk", Test.Repos.Postgres)

      primary_key = table.primary_key
      primary_key_column_names = Enum.map(primary_key.columns, & &1.name)
      assert primary_key_column_names == [:uuid]
      assert_column(table, :uuid, :uuid)
    end

    @tag relations: [:postgres_array_types], adapter: :postgres
    test "correctly handles PostgreSQL array types including character varying[]" do
      {:ok, table} = Database.table("postgres_array_types", Test.Repos.Postgres)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :postgres_array_types
      assert table.adapter == :postgres

      # Verify columns are present and properly structured
      assert is_list(table.columns)

      # Check specific array columns exist with proper types
      assert_column(table, :integer_array, {:array, :integer})
      # This should be converted from "character varying[]" to {:array, :string}
      assert_column(table, :text_array, {:array, :string})
      assert_column(table, :boolean_array, {:array, :boolean})
      assert_column(table, :uuid_array, {:array, :uuid})

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      primary_key_column_names = Enum.map(table.primary_key.columns, & &1.name)
      assert primary_key_column_names == [:id]

      # Verify indices and foreign keys (should be empty for this table)
      assert is_list(table.indices)
      assert is_list(table.foreign_keys)
      assert table.foreign_keys == []
    end

    @tag relations: [:postgres_array_types], adapter: :postgres
    test "correctly converts character varying[] to {:array, :string}" do
      {:ok, table} = Database.table("postgres_array_types", Test.Repos.Postgres)

      # Find the text_array column which should be created as {:array, :string} in migration
      # but stored as "character varying[]" in PostgreSQL
      # Verify that the PostgreSQL "character varying[]" type is correctly converted to {:array, :string}
      assert_column(table, :text_array, {:array, :string},
        nullable: true,
        primary_key: false,
        foreign_key: false
      )
    end
  end

  describe "Database.list_tables/1" do
    @describetag adapter: :postgres

    test "returns list of tables in the database" do
      {:ok, tables} = Database.list_tables(Test.Repos.Postgres)

      assert is_list(tables)
      assert length(tables) > 0

      # Should include some of our test tables
      assert "postgres_types" in tables
      assert "type_mapping_tests" in tables
      assert "special_cases" in tables
      assert "metadata_test" in tables

      # Should not include system tables or migrations
      refute Enum.any?(tables, &String.starts_with?(&1, "pg_"))
      refute "schema_migrations" in tables

      # Tables should be sorted alphabetically
      assert tables == Enum.sort(tables)
    end
  end
end
