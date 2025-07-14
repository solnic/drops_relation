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
      id_column = table[:id]
      assert id_column
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert id_column.type == :integer
      assert id_column.meta.primary_key == true
      assert id_column.meta.nullable == false

      # Check PostgreSQL-specific types
      uuid_column = table[:uuid_type]
      assert uuid_column
      assert uuid_column.type == :uuid

      jsonb_column = table[:jsonb_type]
      assert jsonb_column
      assert jsonb_column.type == :jsonb

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
      id_column = table[:id]
      assert id_column
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert id_column.type == :integer
      assert id_column.meta.primary_key == true
      assert id_column.meta.nullable == false

      integer_type_column = table[:integer_type]
      assert integer_type_column
      assert integer_type_column.type == :integer
      assert integer_type_column.meta.primary_key == false

      text_type_column = table[:text_type]
      assert text_type_column
      assert text_type_column.type == :string

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
      user_id_column = table[:user_id]
      assert user_id_column
      # PostgreSQL references are bigint
      assert user_id_column.type == :integer

      parent_id_column = table[:parent_id]
      assert parent_id_column
      # PostgreSQL references are bigint
      assert parent_id_column.type == :integer

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
      status_column = table[:status]
      assert status_column
      assert status_column.type == :string
      assert status_column.meta.nullable == false
      assert status_column.meta.default == "active"

      # Check nullable description column
      description_column = table[:description]
      assert description_column
      assert description_column.type == :string
      assert description_column.meta.nullable == true

      # Check non-nullable name column
      name_column = table[:name]
      assert name_column
      assert name_column.type == :string
      assert name_column.meta.nullable == false

      # Check priority column with numeric default
      priority_column = table[:priority]
      assert priority_column
      assert priority_column.type == :integer
      assert priority_column.meta.default == 1

      # Check boolean column with default
      is_enabled_column = table[:is_enabled]
      assert is_enabled_column
      assert is_enabled_column.type == :boolean
      assert is_enabled_column.meta.default == true

      # Check score column with check constraints
      score_column = table[:score]
      assert score_column
      assert score_column.type == :integer
      assert score_column.meta.nullable == false
      # Check constraints should be detected
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
      user_id_column = table[:user_id]
      assert user_id_column
      assert user_id_column.type == :integer
      assert user_id_column.meta.foreign_key == true
      assert user_id_column.meta.index == true
      assert is_binary(user_id_column.meta.index_name)

      # Check group_id column - should have foreign_key: true and index: true
      group_id_column = table[:group_id]
      assert group_id_column
      assert group_id_column.type == :integer
      assert group_id_column.meta.foreign_key == true
      assert group_id_column.meta.index == true
      assert is_binary(group_id_column.meta.index_name)

      # Check id column - should have foreign_key: false and index: false
      id_column = table[:id]
      assert id_column
      assert id_column.meta.primary_key == true
      assert id_column.meta.foreign_key == false
      assert id_column.meta.index == false
      assert id_column.meta.index_name == nil

      # Check timestamp columns - should have foreign_key: false and index: false
      inserted_at_column = table[:inserted_at]
      assert inserted_at_column
      assert inserted_at_column.meta.foreign_key == false
      assert inserted_at_column.meta.index == false
      assert inserted_at_column.meta.index_name == nil
    end

    @tag relations: [:custom_pk], adapter: :postgres
    test "correctly handles UUID primary key" do
      {:ok, table} = Database.table("custom_pk", Drops.Relation.Repos.Postgres)

      primary_key = table.primary_key
      id_column = table[:uuid]

      primary_key_column_names = Enum.map(primary_key.columns, & &1.name)
      assert primary_key_column_names == [:uuid]
      assert id_column.type == :uuid
    end

    @tag relations: [:postgres_array_types], adapter: :postgres
    test "correctly handles PostgreSQL array types including character varying[]" do
      {:ok, table} = Database.table("postgres_array_types", Drops.Relation.Repos.Postgres)

      # Verify table structure
      assert %Database.Table{} = table
      assert table.name == :postgres_array_types
      assert table.adapter == :postgres

      # Verify columns are present and properly structured
      assert is_list(table.columns)

      # Check specific array columns exist with proper types
      integer_array_column = table[:integer_array]
      assert integer_array_column
      assert integer_array_column.type == {:array, :integer}

      text_array_column = table[:text_array]
      assert text_array_column
      # This should be converted from "character varying[]" to {:array, :string}
      assert text_array_column.type == {:array, :string}

      boolean_array_column = table[:boolean_array]
      assert boolean_array_column
      assert boolean_array_column.type == {:array, :boolean}

      uuid_array_column = table[:uuid_array]
      assert uuid_array_column
      assert uuid_array_column.type == {:array, :uuid}

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
      {:ok, table} = Database.table("postgres_array_types", Drops.Relation.Repos.Postgres)

      # Find the text_array column which should be created as {:array, :string} in migration
      # but stored as "character varying[]" in PostgreSQL
      text_array_column = table[:text_array]
      assert text_array_column

      # Verify that the PostgreSQL "character varying[]" type is correctly converted to {:array, :string}
      assert text_array_column.type == {:array, :string}

      # Verify the column metadata
      assert text_array_column.meta.nullable == true
      assert text_array_column.meta.primary_key == false
      assert text_array_column.meta.foreign_key == false
    end
  end
end
