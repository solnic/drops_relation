defmodule Drops.Relation.BehavioralTest do
  use Drops.RelationCase, async: false

  describe "Basic CRUD operations with inferred schemas" do
    @tag relations: [:users], adapter: :postgres
    test "basic insert and read operations work", %{users: users} do
      # Test CREATE
      {:ok, user} = users.insert(%{name: "John Doe", email: "john@example.com"})
      assert user.name == "John Doe"
      assert user.email == "john@example.com"
      assert is_integer(user.id)

      # Test READ
      found_user = users.get(user.id)
      assert found_user.name == "John Doe"
      assert found_user.email == "john@example.com"
    end

    @tag relations: [:uuid_organizations], adapter: :postgres
    test "UUID primary keys work correctly", %{uuid_organizations: orgs} do
      # Test CREATE with UUID
      {:ok, org} = orgs.insert(%{name: "Test Organization"})
      assert org.name == "Test Organization"
      assert is_binary(org.id)
      # UUID format
      assert String.length(org.id) == 36

      # Test READ
      found_org = orgs.get(org.id)
      assert found_org.name == "Test Organization"
    end

    @tag relations: [:composite_pk], adapter: :postgres
    test "composite primary keys can be created", %{composite_pk: composite} do
      # Test CREATE with composite PK
      {:ok, record} = composite.insert(%{part1: "key1", part2: 42, data: "test data"})
      assert record.part1 == "key1"
      assert record.part2 == 42
      assert record.data == "test data"
    end
  end

  describe "Schema introspection accuracy" do
    @tag relations: [:users], adapter: :postgres
    test "inferred schema matches expected structure", %{users: users} do
      # Get the actual Ecto schema module from the relation
      schema_module = users.struct().__struct__

      # Check primary key
      assert schema_module.__schema__(:primary_key) == [:id]
      assert schema_module.__schema__(:type, :id) == :id

      # Check field types
      assert schema_module.__schema__(:type, :name) == :string
      assert schema_module.__schema__(:type, :email) == :string

      # Check all fields are present
      fields = schema_module.__schema__(:fields)
      assert :id in fields
      assert :name in fields
      assert :email in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    @tag relations: [:uuid_organizations], adapter: :postgres
    test "UUID schema has correct types", %{uuid_organizations: orgs} do
      schema_module = orgs.struct().__struct__

      # Check primary key is binary_id
      assert schema_module.__schema__(:primary_key) == [:id]
      assert schema_module.__schema__(:type, :id) == :binary_id

      # Check other fields
      assert schema_module.__schema__(:type, :name) == :string
    end

    @tag relations: [:composite_pk], adapter: :postgres
    test "composite primary key schema is correct", %{composite_pk: composite} do
      schema_module = composite.struct().__struct__

      # Check composite primary key
      assert schema_module.__schema__(:primary_key) == [:part1, :part2]
      assert schema_module.__schema__(:type, :part1) == :string
      assert schema_module.__schema__(:type, :part2) == :id
      assert schema_module.__schema__(:type, :data) == :string
    end
  end

  adapters([:sqlite, :postgres]) do
    @describetag relations: [:custom_types], adapter: :postgres

    test "respects SQL functions as defaults", %{custom_types: relation} do
      {:ok, result} = relation.insert(%{})

      assert result.function_default
    end
  end
end
