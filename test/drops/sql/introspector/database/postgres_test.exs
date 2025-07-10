defmodule Drops.SQL.PostgresTest do
  @moduledoc """
  Tests for PostgreSQL database introspection functionality.

  This test suite verifies the full inference behavior by testing against actual
  test tables instead of just testing individual db_type_to_ecto_type function calls.

  The tests verify:
  - Complete schema inference from database tables
  - Correct type mapping from PostgreSQL types to Ecto types
  - Index extraction and metadata
  - Primary key detection
  - Field metadata extraction

  Test tables used:
  - postgres_types: Comprehensive PostgreSQL type testing
  - type_mapping_tests: Cross-database compatibility types
  - postgres_array_types: PostgreSQL array type testing
  """
  use Drops.RelationCase, async: false

  alias Drops.SQL.Postgres
  alias Drops.Relation.Schema.Indices

  describe "get_table_indices/2" do
    @tag relations: [:postgres_types], adapter: :postgres
    test "extracts indices from PostgreSQL database", %{repo: repo} do
      # Create a test table with indices
      Ecto.Adapters.SQL.query!(
        repo,
        """
        DROP TABLE IF EXISTS test_postgres_indices
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE test_postgres_indices (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE,
          name VARCHAR(255),
          status VARCHAR(50)
        )
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE INDEX idx_test_postgres_name ON test_postgres_indices(name)",
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        "CREATE INDEX idx_test_postgres_status_name ON test_postgres_indices(status, name)",
        []
      )

      # Test index extraction
      {:ok, indices} = Postgres.get_table_indices(repo, "test_postgres_indices")

      assert %Indices{} = indices
      assert length(indices.indices) >= 2

      # Find the specific indices we created
      name_index = Enum.find(indices.indices, &(&1.name == "idx_test_postgres_name"))

      composite_index =
        Enum.find(indices.indices, &(&1.name == "idx_test_postgres_status_name"))

      assert name_index
      assert length(name_index.fields) == 1
      assert hd(name_index.fields).name == :name
      assert name_index.unique == false

      assert composite_index
      assert length(composite_index.fields) == 2
      assert Enum.map(composite_index.fields, & &1.name) == [:status, :name]
      assert composite_index.unique == false

      # Clean up
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE test_postgres_indices", [])
    end

    @tag relations: [:postgres_types], adapter: :postgres
    test "handles table with no custom indices", %{repo: repo} do
      # Create a simple table with no custom indices
      Ecto.Adapters.SQL.query!(
        repo,
        """
        DROP TABLE IF EXISTS test_postgres_no_indices
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE test_postgres_no_indices (
          id SERIAL PRIMARY KEY,
          data TEXT
        )
        """,
        []
      )

      {:ok, indices} = Postgres.get_table_indices(repo, "test_postgres_no_indices")

      assert %Indices{} = indices
      # Should have no custom indices (primary key indices are excluded)
      assert length(indices.indices) == 0

      # Clean up
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE test_postgres_no_indices", [])
    end

    @tag relations: [:postgres_types], adapter: :postgres
    test "returns empty indices for non-existent table", %{repo: repo} do
      # PostgreSQL should return empty results for non-existent tables
      {:ok, indices} = Postgres.get_table_indices(repo, "non_existent_table")
      assert %Indices{} = indices
      assert indices.indices == []
    end
  end

  describe "introspect_table_columns/2" do
    @tag relations: [:postgres_types], adapter: :postgres
    test "extracts column information from PostgreSQL table", %{repo: repo} do
      # Create a test table
      Ecto.Adapters.SQL.query!(
        repo,
        """
        DROP TABLE IF EXISTS test_postgres_columns
        """,
        []
      )

      Ecto.Adapters.SQL.query!(
        repo,
        """
        CREATE TABLE test_postgres_columns (
          id SERIAL PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          email VARCHAR(255) UNIQUE,
          age INTEGER,
          active BOOLEAN DEFAULT true,
          created_at TIMESTAMP DEFAULT NOW()
        )
        """,
        []
      )

      {:ok, columns} = Postgres.introspect_table_columns(repo, "test_postgres_columns")

      assert is_list(columns)
      assert length(columns) == 6

      # Check specific columns
      id_column = Enum.find(columns, &(&1.name == "id"))
      name_column = Enum.find(columns, &(&1.name == "name"))
      email_column = Enum.find(columns, &(&1.name == "email"))

      assert id_column
      assert id_column.type == "integer"
      assert id_column.primary_key == true
      assert id_column.nullable == false

      assert name_column
      assert name_column.type == "character varying"
      assert name_column.nullable == false

      assert email_column
      assert email_column.type == "character varying"

      # Clean up
      Ecto.Adapters.SQL.query!(repo, "DROP TABLE test_postgres_columns", [])
    end
  end

  describe "full inference behavior" do
    @tag relations: [:postgres_types], adapter: :postgres
    test "infers correct Ecto types from postgres_types test table", %{repo: repo} do
      alias Drops.SQL.Inference

      # Test full schema inference from the postgres_types table
      schema = Inference.infer_from_table("postgres_types", repo)

      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "postgres_types"

      # Verify we have the expected number of fields (including id)
      assert length(schema.fields) > 20

      # Test integer types
      assert_field_type(schema, :smallint_type, :integer)
      assert_field_type(schema, :int2_type, :integer)
      assert_field_type(schema, :integer_type, :integer)
      assert_field_type(schema, :int_type, :integer)
      assert_field_type(schema, :int4_type, :integer)
      assert_field_type(schema, :bigint_type, :integer)
      assert_field_type(schema, :int8_type, :integer)

      # Test serial types (should be inferred as integer)
      assert_field_type(schema, :serial_type, :integer)
      assert_field_type(schema, :bigserial_type, :integer)

      # Test floating point types
      assert_field_type(schema, :real_type, :float)
      assert_field_type(schema, :float4_type, :float)
      assert_field_type(schema, :double_precision_type, :float)
      assert_field_type(schema, :float8_type, :float)

      # Test decimal types
      assert_field_type(schema, :numeric_type, :decimal)
      assert_field_type(schema, :decimal_type, :decimal)
      assert_field_type(schema, :money_type, :decimal)

      # Test string types
      assert_field_type(schema, :varchar_type, :string)
      assert_field_type(schema, :char_type, :string)
      assert_field_type(schema, :text_type, :string)

      # Test date/time types
      assert_field_type(schema, :date_type, :date)
      assert_field_type(schema, :time_type, :time)
      assert_field_type(schema, :time_with_tz_type, :time)
      assert_field_type(schema, :timestamp_type, :naive_datetime)
      assert_field_type(schema, :timestamp_with_tz_type, :utc_datetime)

      # Test special types
      assert_field_type(schema, :boolean_type, :boolean)
      # UUID type: normalized to :binary (ecto_type is :binary_id)
      assert_field_type(schema, :uuid_type, :binary)
      assert_field_type(schema, :json_type, :map)
      assert_field_type(schema, :jsonb_type, :map)
      assert_field_type(schema, :bytea_type, :binary)

      # Test additional string types
      assert_field_type(schema, :character_varying_type, :string)
      assert_field_type(schema, :character_type, :string)
      assert_field_type(schema, :name_type, :string)
      assert_field_type(schema, :xml_type, :string)

      # Test network types (should be mapped to string)
      assert_field_type(schema, :inet_type, :string)
      assert_field_type(schema, :cidr_type, :string)
      assert_field_type(schema, :macaddr_type, :string)

      # Verify primary key is correctly identified
      assert %Drops.Relation.Schema.PrimaryKey{} = schema.primary_key
      assert length(schema.primary_key.fields) == 1
      pk_field = hd(schema.primary_key.fields)
      assert pk_field.name == :id
      assert pk_field.type == :integer

      # Verify indices are extracted
      assert %Drops.Relation.Schema.Indices{} = schema.indices
      # Should have at least the indices created in migration
      assert length(schema.indices.indices) >= 2

      # Find specific indices
      integer_index =
        Enum.find(
          schema.indices.indices,
          &(&1.name == "postgres_types_integer_type_index")
        )

      uuid_unique_index =
        Enum.find(schema.indices.indices, &(&1.name == "postgres_types_uuid_type_index"))

      composite_index =
        Enum.find(
          schema.indices.indices,
          &(&1.name == "postgres_types_varchar_type_text_type_index")
        )

      assert integer_index
      assert length(integer_index.fields) == 1
      assert hd(integer_index.fields).name == :integer_type
      assert integer_index.unique == false

      assert uuid_unique_index
      assert length(uuid_unique_index.fields) == 1
      assert hd(uuid_unique_index.fields).name == :uuid_type
      assert uuid_unique_index.unique == true

      assert composite_index
      assert length(composite_index.fields) == 2
      field_names = Enum.map(composite_index.fields, & &1.name)
      assert field_names == [:varchar_type, :text_type]
      assert composite_index.unique == false
    end

    @tag relations: [:type_mapping_tests], adapter: :postgres
    test "infers correct types from type_mapping_tests table", %{repo: repo} do
      alias Drops.SQL.Inference

      # Test inference from the type_mapping_tests table
      schema = Inference.infer_from_table("type_mapping_tests", repo)

      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "type_mapping_tests"

      # Test basic types from type_mapping_tests (using actual field names from migration)
      assert_field_type(schema, :integer_type, :integer)
      assert_field_type(schema, :real_type, :float)
      assert_field_type(schema, :text_type, :string)
      assert_field_type(schema, :blob_type, :binary)
      assert_field_type(schema, :numeric_type, :decimal)
      assert_field_type(schema, :boolean_type, :boolean)
      assert_field_type(schema, :date_type, :date)
      assert_field_type(schema, :datetime_type, :naive_datetime)
      assert_field_type(schema, :timestamp_type, :naive_datetime)
      assert_field_type(schema, :time_type, :time)
      assert_field_type(schema, :decimal_precision_type, :decimal)
      assert_field_type(schema, :float_type, :float)
      assert_field_type(schema, :double_type, :float)
      assert_field_type(schema, :varchar_type, :string)
      assert_field_type(schema, :char_type, :string)
      assert_field_type(schema, :clob_type, :string)
      assert_field_type(schema, :json_type, :map)

      # Verify indices from migration
      assert %Drops.Relation.Schema.Indices{} = schema.indices
      assert length(schema.indices.indices) >= 2

      # Find specific indices
      integer_index =
        Enum.find(
          schema.indices.indices,
          &(&1.name == "type_mapping_tests_integer_type_index")
        )

      text_unique_index =
        Enum.find(
          schema.indices.indices,
          &(&1.name == "type_mapping_tests_text_type_index")
        )

      composite_index =
        Enum.find(
          schema.indices.indices,
          &(&1.name == "type_mapping_tests_boolean_type_date_type_index")
        )

      assert integer_index
      assert text_unique_index
      assert text_unique_index.unique == true
      assert composite_index
      assert length(composite_index.fields) == 2
    end

    @tag relations: [:postgres_array_types], adapter: :postgres
    test "infers array types from postgres_array_types table", %{repo: repo} do
      alias Drops.SQL.Inference

      schema = Inference.infer_from_table("postgres_array_types", repo)

      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "postgres_array_types"

      # Array types should now be correctly inferred
      assert_field_type(schema, :integer_array, {:array, :integer})
      assert_field_type(schema, :text_array, {:array, :string})
      assert_field_type(schema, :boolean_array, {:array, :boolean})
      assert_field_type(schema, :uuid_array, {:array, :binary})
    end
  end

  # Helper function to assert field type
  defp assert_field_type(schema, field_name, expected_type) do
    field = Enum.find(schema.fields, &(&1.name == field_name))
    assert field, "Field #{field_name} not found in schema"

    assert field.type == expected_type,
           "Expected field #{field_name} to have type #{inspect(expected_type)}, got #{inspect(field.type)}"
  end
end
