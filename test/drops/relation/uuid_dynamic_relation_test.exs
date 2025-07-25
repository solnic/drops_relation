defmodule Drops.Relation.UuidDynamicRelationTest do
  use Test.RelationCase, async: false

  describe "uuid dynamic relations" do
    @tag relations: [:uuid_organizations], adapter: :sqlite
    test "generates correct @primary_key attribute for uuid", %{
      uuid_organizations: orgs
    } do
      # Get the generated schema module
      schema_module = orgs.__schema_module__()

      # Check that the schema has the correct primary key configuration
      primary_key = schema_module.__schema__(:primary_key)
      assert primary_key == [:id]

      # Check the field type for the primary key
      id_type = schema_module.__schema__(:type, :id)
      assert id_type == :binary_id

      # Check the Drops schema for comparison
      drops_relation_schema = orgs.schema()
      assert drops_relation_schema.source == :uuid_organizations

      # Verify primary key field has correct types
      pk_field = hd(drops_relation_schema.primary_key.fields)
      assert pk_field.name == :id
      assert pk_field.type == :binary_id
      assert pk_field.meta.type == :uuid

      # Verify the module was generated with @primary_key attribute
      # We can't directly inspect module attributes, but we can check the behavior
      # by trying to create a struct and seeing if it has the right field types
      struct = struct(schema_module)
      assert Map.has_key?(struct, :id)
    end

    @tag relations: [:uuid_users], adapter: :sqlite
    test "generates correct @foreign_key_type attribute for uuid FKs", %{
      uuid_users: users
    } do
      # Get the generated schema module
      schema_module = users.__schema_module__()

      org_id_type = schema_module.__schema__(:type, :organization_id)
      assert org_id_type == :binary_id

      # Verify the struct has the foreign key field
      struct = struct(schema_module)
      assert Map.has_key?(struct, :organization_id)
    end

    @tag relations: [:uuid_posts], adapter: :sqlite
    test "handles nested uuid foreign keys correctly", %{uuid_posts: posts} do
      # Get the generated schema module
      schema_module = posts.__schema_module__()

      # Check primary key
      primary_key = schema_module.__schema__(:primary_key)
      assert primary_key == [:id]

      id_type = schema_module.__schema__(:type, :id)
      assert id_type == :binary_id

      # Check foreign key
      user_id_type = schema_module.__schema__(:type, :user_id)
      assert user_id_type == :binary_id

      # Verify all expected fields exist
      struct = struct(schema_module)
      assert Map.has_key?(struct, :id)
      assert Map.has_key?(struct, :title)
      assert Map.has_key?(struct, :content)
      assert Map.has_key?(struct, :user_id)
    end

    @tag relations: [:uuid_organizations, :uuid_users], adapter: :sqlite
    test "uuid relations work with basic CRUD operations", %{
      uuid_organizations: orgs,
      uuid_users: users
    } do
      # Test that we can perform basic operations without type errors

      # Create an organization
      org_id = Ecto.UUID.generate()
      org_attrs = %{id: org_id, name: "Test Org"}

      # Insert should work (we're testing the schema generation, not the actual DB operation)
      # The important thing is that the schema accepts binary_id values
      org_struct = struct(orgs.__schema_module__(), org_attrs)
      assert org_struct.id == org_id
      assert org_struct.name == "Test Org"

      # Create a user with binary_id foreign key
      user_id = Ecto.UUID.generate()

      user_attrs = %{
        id: user_id,
        name: "Test User",
        email: "test@example.com",
        organization_id: org_id
      }

      user_struct = struct(users.__schema_module__(), user_attrs)
      assert user_struct.id == user_id
      assert user_struct.organization_id == org_id
    end
  end

  describe "mixed primary key types" do
    @tag relations: [:users, :uuid_users], adapter: :sqlite
    test "handles both integer and uuid primary keys in same test", %{
      users: int_users,
      uuid_users: uuid_users
    } do
      # Integer PK relation
      int_schema = int_users.__schema_module__()
      int_id_type = int_schema.__schema__(:type, :id)
      assert int_id_type == :id

      # UUID PK relation
      uuid_schema = uuid_users.__schema_module__()
      uuid_id_type = uuid_schema.__schema__(:type, :id)
      assert uuid_id_type == :binary_id

      # Verify they're different
      assert int_id_type != uuid_id_type
    end
  end

  describe "schema introspection" do
    @tag relations: [:uuid_users], adapter: :sqlite
    test "schema introspection returns correct field information", %{
      uuid_users: users
    } do
      # Get the Drops schema information
      drops_relation_schema = users.schema()

      # Check that the schema has the correct source
      assert drops_relation_schema.source == :uuid_users

      # Check primary key information
      assert length(drops_relation_schema.primary_key.fields) == 1
      pk_field = hd(drops_relation_schema.primary_key.fields)
      assert pk_field.name == :id
      assert pk_field.type == :binary_id

      # Check that UUID foreign key fields are properly typed
      org_id_field = Enum.find(drops_relation_schema.fields, &(&1.name == :organization_id))
      assert org_id_field
      assert org_id_field.type == :binary_id
    end
  end

  describe "PostgreSQL UUID support" do
    @tag relations: [:uuid_organizations], adapter: :postgres
    test "PostgreSQL generates correct @primary_key attribute for uuid", %{
      uuid_organizations: orgs
    } do
      # Get the generated schema module
      schema_module = orgs.__schema_module__()

      # Check that the schema has the correct primary key configuration
      primary_key = schema_module.__schema__(:primary_key)
      assert primary_key == [:id]

      # Check the field type for the primary key
      id_type = schema_module.__schema__(:type, :id)
      assert id_type == :binary_id

      # Check the Drops schema for comparison
      drops_relation_schema = orgs.schema()
      assert drops_relation_schema.source == :uuid_organizations

      # Verify primary key field has correct types
      pk_field = hd(drops_relation_schema.primary_key.fields)
      assert pk_field.name == :id
      assert pk_field.type == :binary_id
      assert pk_field.meta.type == :uuid
    end

    @tag relations: [:uuid_users], adapter: :postgres
    test "PostgreSQL generates correct @foreign_key_type attribute for uuid FKs", %{
      uuid_users: users
    } do
      # Get the generated schema module
      schema_module = users.__schema_module__()

      # Check that foreign key fields have binary_id type
      org_id_type = schema_module.__schema__(:type, :organization_id)
      assert org_id_type == :binary_id

      # Verify the struct has the foreign key field
      struct = struct(schema_module)
      assert Map.has_key?(struct, :organization_id)
    end
  end
end
