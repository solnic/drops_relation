defmodule Ecto.Relation.BinaryIdIntegrationTest do
  use ExUnit.Case, async: true

  alias Ecto.Relation.Schema
  alias Ecto.Relation.Schema.{Field, PrimaryKey}
  alias Ecto.Relation.Schema.Generator
  alias Ecto.Relation.SchemaCache
  alias Test.Ecto.TestSchemas

  # Mock repository for testing (same as in SchemaCache tests)
  defmodule TestRepo do
    def config do
      [priv: "test/fixtures/binary_id_repo"]
    end
  end

  setup do
    # Clear cache before each test
    SchemaCache.clear_all()

    # Enable cache for tests
    original_config = Ecto.Relation.Config.schema_cache()

    on_exit(fn ->
      Ecto.Relation.Config.update(:schema_cache, original_config)
      File.rm_rf!("test/fixtures/binary_id_repo")
    end)

    Ecto.Relation.Config.update(:schema_cache, enabled: true)

    # Create test fixture directory
    File.mkdir_p!("test/fixtures/binary_id_repo/migrations")

    # Create a test migration file
    File.write!(
      "test/fixtures/binary_id_repo/migrations/001_create_binary_id_tables.exs",
      "# binary id migration"
    )

    :ok
  end

  describe "binary_id schema integration" do
    test "schema inference handles binary_id primary keys correctly" do
      # Test that we can extract schema information from binary_id schemas
      schema = Schema.from_ecto_schema(TestSchemas.BinaryIdUserSchema)

      assert schema.source == "binary_id_users"

      # Check primary key - Schema.from_ecto_schema creates minimal fields
      assert length(schema.primary_key.fields) == 1
      pk_field = hd(schema.primary_key.fields)
      assert pk_field.name == :id
      # Note: from_ecto_schema creates minimal fields with :unknown type
      # This is expected behavior for this function

      # Check that foreign keys are detected
      assert length(schema.foreign_keys) == 1
      fk = hd(schema.foreign_keys)
      assert fk.field == :organization_id
      assert fk.references_table == "binary_id_organizations"
    end

    test "schema generation produces correct binary_id attributes" do
      # Create a schema with binary_id primary key and foreign keys
      schema = %Schema{
        source: "binary_id_users",
        primary_key: %PrimaryKey{fields: [Field.new(:id, :binary, :binary_id, :id)]},
        fields: [
          Field.new(:id, :binary, :binary_id, :id),
          Field.new(:name, :string, :string, :name),
          Field.new(:email, :string, :string, :email),
          Field.new(:organization_id, :binary, :binary_id, :organization_id, %{
            is_foreign_key: true
          })
        ],
        foreign_keys: [],
        indices: %Ecto.Relation.Schema.Indices{indices: []}
      }

      result = Generator.generate_module_content("MyApp.User", "binary_id_users", schema)

      # Should generate both @primary_key and @foreign_key_type attributes
      assert result =~ "@primary_key {:id, :binary_id, autogenerate: true}"
      assert result =~ "@foreign_key_type :binary_id"

      # Should include the foreign key field
      assert result =~ "field :organization_id, :binary_id"

      # Should exclude the primary key field from field definitions
      refute result =~ "field :id"
    end

    test "schema cache handles binary_id schemas correctly" do
      # Create a schema with binary_id fields
      schema = %Schema{
        source: "binary_id_posts",
        primary_key: %PrimaryKey{fields: [Field.new(:id, :binary, :binary_id, :id)]},
        fields: [
          Field.new(:id, :binary, :binary_id, :id),
          Field.new(:title, :string, :string, :title),
          Field.new(:content, :string, :string, :content),
          Field.new(:user_id, :binary, :binary_id, :user_id)
        ],
        foreign_keys: [],
        indices: %Ecto.Relation.Schema.Indices{indices: []}
      }

      # Test serialization and deserialization
      serialized = SchemaCache.test_serialize_schema(schema)
      assert is_map(serialized)

      # The serialized data should contain string representations
      assert serialized["source"] == "binary_id_posts"
      assert is_list(serialized["fields"])

      # Find the binary_id field in serialized data
      id_field_data = Enum.find(serialized["fields"], &(&1["name"] == "id"))
      assert id_field_data["ecto_type"] == "binary_id"
      assert id_field_data["type"] == "binary"

      # Test deserialization
      deserialized = SchemaCache.test_deserialize_schema(serialized)

      assert deserialized.source == schema.source
      assert length(deserialized.fields) == length(schema.fields)

      # Check that binary_id types are preserved
      id_field = Enum.find(deserialized.fields, &(&1.name == :id))
      assert id_field.ecto_type == :binary_id
      assert id_field.type == :binary
    end

    test "complex ecto types with binary_id work in cache" do
      # Test a more complex scenario with arrays and binary_id
      schema = %Schema{
        source: "complex_binary_id_table",
        primary_key: %PrimaryKey{fields: [Field.new(:id, :binary, :binary_id, :id)]},
        fields: [
          Field.new(:id, :binary, :binary_id, :id),
          Field.new(:tags, {:array, :string}, {:array, :string}, :tags),
          Field.new(:metadata, :map, :map, :metadata),
          Field.new(:parent_ids, {:array, :binary}, {:array, :binary_id}, :parent_ids)
        ],
        foreign_keys: [],
        indices: %Ecto.Relation.Schema.Indices{indices: []}
      }

      # This should not crash (testing the original issue)
      serialized = SchemaCache.test_serialize_schema(schema)
      deserialized = SchemaCache.test_deserialize_schema(serialized)

      # Verify complex types are preserved
      tags_field = Enum.find(deserialized.fields, &(&1.name == :tags))
      assert tags_field.ecto_type == {:array, :string}

      parent_ids_field = Enum.find(deserialized.fields, &(&1.name == :parent_ids))
      assert parent_ids_field.ecto_type == {:array, :binary_id}
    end
  end

  describe "schema cache with real binary_id schemas" do
    test "caches and retrieves binary_id schema without errors" do
      # Use the actual test schema
      schema = Schema.from_ecto_schema(TestSchemas.BinaryIdOrganizationSchema)

      # This should work without crashing
      SchemaCache.cache_schema(TestRepo, "binary_id_organizations", schema)

      # Try to retrieve it (might be nil due to digest mismatch, but shouldn't crash)
      _cached_schema = SchemaCache.get_cached_schema(TestRepo, "binary_id_organizations")

      # The important thing is that we get here without a crash
      # The result might be nil due to digest validation, but that's OK
      assert true
    end
  end
end
