defmodule Drops.Relations.SchemaSpec do
  use Drops.RelationCase, async: false

  describe "basic schema inference" do
    @tag relations: [:users]

    test "infers basic fields from users table", %{users: users} do
      assert users.ecto_schema(:fields) == [
               :id,
               :name,
               :email,
               :age,
               :inserted_at,
               :updated_at
             ]

      assert users.ecto_schema(:type, :id) == :id
      assert users.ecto_schema(:type, :name) == :string
      assert users.ecto_schema(:type, :email) == :string
      assert users.ecto_schema(:type, :age) == :integer
      assert users.ecto_schema(:type, :inserted_at) == :naive_datetime
      assert users.ecto_schema(:type, :updated_at) == :naive_datetime
    end
  end

  describe "different field types" do
    @tag relations: [:basic_types]
    test "infers various field types correctly", %{basic_types: basic_types} do
      fields = basic_types.ecto_schema(:fields)

      # Should include all non-timestamp fields
      assert :id in fields
      assert :string_field in fields
      assert :integer_field in fields
      assert :float_field in fields
      assert :boolean_field in fields
      assert :binary_field in fields
      assert :bitstring_field in fields

      # Check types
      assert basic_types.ecto_schema(:type, :string_field) == :string
      assert basic_types.ecto_schema(:type, :integer_field) == :integer
      assert basic_types.ecto_schema(:type, :float_field) == :decimal
      # TODO: add custom ecto type called Boolean for Sqlite inference
      assert basic_types.ecto_schema(:type, :boolean_field) == :integer
      assert basic_types.ecto_schema(:type, :binary_field) == :binary
    end
  end

  describe "primary keys" do
    @tag relations: [:custom_pk]
    test "handles custom primary keys", %{custom_pk: custom_pk} do
      fields = custom_pk.ecto_schema(:fields)

      # Should include the custom primary key and other fields
      assert :uuid in fields
      assert :name in fields

      # The default :id should NOT be present when using custom primary key
      refute :id in fields
    end

    @tag relations: [:no_pk]
    test "handles tables without primary keys", %{no_pk: no_pk} do
      fields = no_pk.ecto_schema(:fields)

      # Should include all fields
      # Ecto still adds this
      assert :id in fields
      assert :name in fields
      assert :value in fields
    end
  end

  describe "foreign keys and associations" do
    @tag relations: [:associations, :association_items, :association_parents]
    test "infers foreign key fields", %{associations: associations} do
      fields = associations.ecto_schema(:fields)

      # Should include foreign key fields
      assert :id in fields
      assert :name in fields
      # belongs_to association
      assert :parent_id in fields

      # Check that foreign key has correct type
      assert associations.ecto_schema(:type, :parent_id) == :id
    end

    @tag relations: [:associations, :association_items, :association_parents]
    test "infers association item foreign keys", %{association_items: association_items} do
      fields = association_items.ecto_schema(:fields)

      # Should include foreign key fields
      assert :id in fields
      assert :title in fields
      # belongs_to association
      assert :association_id in fields

      # Check that foreign key has correct type
      assert association_items.ecto_schema(:type, :association_id) == :id
    end
  end

  describe "timestamp handling" do
    @tag relations: [:timestamps]
    test "includes timestamp fields in inference by default", %{timestamps: timestamps} do
      fields = timestamps.ecto_schema(:fields)

      # Should include regular fields and timestamps
      assert :id in fields
      assert :name in fields

      # Timestamps should be included in inference by default
      assert :inserted_at in fields
      assert :updated_at in fields
    end
  end

  describe "automatic schema storage" do
    @tag relations: [:users]
    test "automatically stores Drops.Relation.Schema", %{users: users} do
      schema = users.schema()

      # Should be a Drops.Relation.Schema struct
      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "users"

      # Should have primary key information
      assert Drops.Relation.Schema.PrimaryKey.field_names(schema.primary_key) == [:id]

      # Should have field metadata
      assert length(schema.fields) > 0
      assert Enum.any?(schema.fields, &(&1.name == :name))
      assert Enum.any?(schema.fields, &(&1.name == :email))

      # Should have empty foreign keys for simple schema
      assert schema.foreign_keys == []
    end

    @tag relations: [:associations, :association_items, :association_parents]
    test "stores schema with foreign keys and associations", %{associations: associations} do
      schema = associations.schema()

      # Should be a Drops.Relation.Schema struct
      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "associations"

      # Should have primary key information
      assert Drops.Relation.Schema.PrimaryKey.field_names(schema.primary_key) == [:id]

      # Should have field metadata including foreign keys
      assert length(schema.fields) > 0
      parent_id_field = Enum.find(schema.fields, &(&1.name == :parent_id))
      assert parent_id_field != nil
      assert parent_id_field.type == :integer
      assert parent_id_field.ecto_type == :id

      # Database introspection correctly detects foreign key constraints
      # even though association metadata is defined in Ecto schema code.
      # Foreign key constraints exist in the database and should be detected.
      assert length(schema.foreign_keys) == 1
      fk = hd(schema.foreign_keys)
      assert fk.field == :parent_id
      assert fk.references_table == "association_parents"
      assert fk.references_field == :id

      # Association name is nil because this comes from database introspection, not Ecto schema
      assert fk.association_name == nil
    end

    @tag relations: [:composite_pk]
    test "stores schema with composite primary key", %{composite_pk: composite_pk} do
      schema = composite_pk.schema()

      # Should be a Drops.Relation.Schema struct
      assert %Drops.Relation.Schema{} = schema
      assert schema.source == "composite_pk"

      # Database introspection correctly detects composite primary keys
      # defined with @primary_key false and field-level primary_key: true
      # SQLite PRAGMA table_info properly shows all primary key columns.
      assert Drops.Relation.Schema.PrimaryKey.field_names(schema.primary_key) == [
               :part1,
               :part2
             ]

      assert Drops.Relation.Schema.composite_primary_key?(schema)
    end
  end

  describe "customizing fields" do
    relation(:users) do
      field(:tags, Ecto.Enum, values: [:red, :green, :blue])
      field(:status, :string, default: "active")
    end

    test "custom fields are respected", %{users: users} do
      # Verify that custom fields are included in the schema
      fields = users.ecto_schema(:fields)

      assert :tags in fields
      assert :status in fields

      # Verify the custom field types
      tags_type = users.ecto_schema(:type, :tags)
      assert match?({:parameterized, {Ecto.Enum, _}}, tags_type)
      assert users.ecto_schema(:type, :status) == :string

      # Verify that inferred fields are still present
      assert :name in fields
      assert :email in fields
      assert :age in fields
    end

    test "custom fields override inferred fields", %{users: users} do
      # The 'name' field exists in the database as :string, but we didn't override it,
      # so it should still be the inferred type
      fields = users.ecto_schema(:fields)
      assert :name in fields

      # Should still be string since we didn't override it
      assert users.ecto_schema(:type, :name) == :string
    end
  end

  describe "overriding inferred fields" do
    relation(:users) do
      # Override the 'name' field that exists in the database
      field(:name, :binary)
    end

    test "custom field definitions override inferred ones", %{users: users} do
      fields = users.ecto_schema(:fields)

      # The name field should be present (it's overridden but still a real field)
      assert :name in fields

      # The name field should be overridden to :binary instead of the inferred :string
      assert users.ecto_schema(:type, :name) == :binary

      # Other inferred fields should still be present
      assert :email in fields
      assert :age in fields
    end

    test "can insert and query with overridden fields", %{users: users} do
      # Test that we can actually use the overridden fields in database operations
      {:ok, user} =
        users.insert(%{
          # This will be stored as binary due to our override
          name: "Test User",
          email: "test@example.com",
          age: 25
        })

      assert user.name == "Test User"

      # Verify we can query it back
      found_user = users.get(user.id)
      assert found_user.name == "Test User"
    end
  end
end
