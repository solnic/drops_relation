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
      id_column = Enum.find(table.columns, &(&1.name == :id))
      assert id_column
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert id_column.type == "bigint"
      assert id_column.meta.primary_key == true
      assert id_column.meta.nullable == false

      # Check PostgreSQL-specific types
      uuid_column = Enum.find(table.columns, &(&1.name == :uuid_type))
      assert uuid_column
      assert uuid_column.type == "uuid"

      jsonb_column = Enum.find(table.columns, &(&1.name == :jsonb_type))
      assert jsonb_column
      assert jsonb_column.type == "jsonb"

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert table.primary_key.columns == [:id]

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
      id_column = Enum.find(table.columns, &(&1.name == :id))
      assert id_column
      # PostgreSQL SERIAL PRIMARY KEY is bigint
      assert id_column.type == "bigint"
      assert id_column.meta.primary_key == true
      assert id_column.meta.nullable == false

      integer_type_column = Enum.find(table.columns, &(&1.name == :integer_type))
      assert integer_type_column
      assert integer_type_column.type == "integer"
      assert integer_type_column.meta.primary_key == false

      text_type_column = Enum.find(table.columns, &(&1.name == :text_type))
      assert text_type_column
      assert text_type_column.type == "text"

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert table.primary_key.columns == [:id]

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
      user_id_column = Enum.find(table.columns, &(&1.name == :user_id))
      assert user_id_column
      # PostgreSQL references are bigint
      assert user_id_column.type == "bigint"

      parent_id_column = Enum.find(table.columns, &(&1.name == :parent_id))
      assert parent_id_column
      # PostgreSQL references are bigint
      assert parent_id_column.type == "bigint"

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
      assert table.primary_key.columns == [:id]

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
      status_column = Enum.find(table.columns, &(&1.name == :status))
      assert status_column
      assert status_column.type == "character varying"
      assert status_column.meta.nullable == false
      assert status_column.meta.default == "active"

      # Check nullable description column
      description_column = Enum.find(table.columns, &(&1.name == :description))
      assert description_column
      assert description_column.type == "text"
      assert description_column.meta.nullable == true

      # Check non-nullable name column
      name_column = Enum.find(table.columns, &(&1.name == :name))
      assert name_column
      assert name_column.type == "character varying"
      assert name_column.meta.nullable == false

      # Check priority column with numeric default
      priority_column = Enum.find(table.columns, &(&1.name == :priority))
      assert priority_column
      assert priority_column.type == "integer"
      assert priority_column.meta.default == 1

      # Check boolean column with default
      is_enabled_column = Enum.find(table.columns, &(&1.name == :is_enabled))
      assert is_enabled_column
      assert is_enabled_column.type == "boolean"
      assert is_enabled_column.meta.default == true

      # Check score column with check constraints
      score_column = Enum.find(table.columns, &(&1.name == :score))
      assert score_column
      assert score_column.type == "integer"
      assert score_column.meta.nullable == false
      # Check constraints should be detected
      assert is_list(score_column.meta.check_constraints)

      # Verify primary key
      assert %Database.PrimaryKey{} = table.primary_key
      assert table.primary_key.columns == [:id]

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
  end
end
