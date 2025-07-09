defmodule Drops.Relation.SchemaTest do
  use ExUnit.Case, async: false

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{PrimaryKey, ForeignKey, Indices}
  alias Test.Ecto.TestSchemas

  describe "new/6" do
    test "creates schema with all metadata" do
      pk = PrimaryKey.new([:id])
      fk = ForeignKey.new(:user_id, "users", :id, :user)

      fields = [
        %{name: :id, type: :integer, ecto_type: :id, source: :id},
        %{name: :user_id, type: :integer, ecto_type: :id, source: :user_id}
      ]

      indices = Indices.new([])

      schema = Schema.new("posts", pk, [fk], fields, indices)

      assert schema.source == "posts"
      assert schema.primary_key == pk
      assert schema.foreign_keys == [fk]
      assert schema.fields == fields
      assert schema.indices == indices
    end
  end

  describe "from_ecto_schema/2" do
    test "creates schema from Ecto schema without repo" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      assert schema.source == "users"
      assert PrimaryKey.field_names(schema.primary_key) == [:id]
      assert schema.foreign_keys == []
      assert length(schema.fields) > 0
      assert Enum.any?(schema.fields, &(&1.name == :name))
      assert Enum.any?(schema.fields, &(&1.name == :email))
      # No repo provided
      assert Indices.empty?(schema.indices)
    end

    test "creates schema from Ecto schema with foreign keys" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      assert schema.source == "associations"
      assert PrimaryKey.field_names(schema.primary_key) == [:id]
      assert length(schema.foreign_keys) == 1

      fk = hd(schema.foreign_keys)
      assert fk.field == :parent_id
      assert fk.references_table == "association_parents"
      assert fk.association_name == :parent
    end

    test "creates schema with composite primary key" do
      schema = Schema.from_ecto_schema(TestSchemas.CompositePrimaryKeySchema)

      assert schema.source == "composite_pk"
      assert PrimaryKey.field_names(schema.primary_key) == [:part1, :part2]
      assert Schema.composite_primary_key?(schema)
    end
  end

  describe "find_field/2" do
    setup do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)
      {:ok, schema: schema}
    end

    test "finds existing field", %{schema: schema} do
      field = Schema.find_field(schema, :name)

      assert field != nil
      assert field.name == :name
      assert field.type == :string
    end

    test "returns nil for non-existent field", %{schema: schema} do
      field = Schema.find_field(schema, :non_existent)

      assert field == nil
    end
  end

  describe "primary_key_field?/2" do
    test "returns true for primary key field" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      assert Schema.primary_key_field?(schema, :id)
    end

    test "returns false for non-primary key field" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      refute Schema.primary_key_field?(schema, :name)
    end

    test "works with composite primary key" do
      schema = Schema.from_ecto_schema(TestSchemas.CompositePrimaryKeySchema)

      assert Schema.primary_key_field?(schema, :part1)
      assert Schema.primary_key_field?(schema, :part2)
      refute Schema.primary_key_field?(schema, :data)
    end
  end

  describe "foreign_key_field?/2" do
    test "returns true for foreign key field" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      assert Schema.foreign_key_field?(schema, :parent_id)
    end

    test "returns false for non-foreign key field" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      refute Schema.foreign_key_field?(schema, :name)
    end

    test "returns false when no foreign keys exist" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      refute Schema.foreign_key_field?(schema, :id)
    end
  end

  describe "get_foreign_key/2" do
    test "returns foreign key information" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      fk = Schema.get_foreign_key(schema, :parent_id)

      assert fk != nil
      assert fk.field == :parent_id
      assert fk.references_table == "association_parents"
      assert fk.references_field == :id
    end

    test "returns nil for non-foreign key field" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      fk = Schema.get_foreign_key(schema, :name)

      assert fk == nil
    end
  end

  describe "composite_primary_key?/1" do
    test "returns false for single primary key" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      refute Schema.composite_primary_key?(schema)
    end

    test "returns true for composite primary key" do
      schema = Schema.from_ecto_schema(TestSchemas.CompositePrimaryKeySchema)

      assert Schema.composite_primary_key?(schema)
    end

    test "returns false for no primary key" do
      schema = Schema.from_ecto_schema(TestSchemas.NoPrimaryKeySchema)

      refute Schema.composite_primary_key?(schema)
    end
  end

  describe "field_names/1" do
    test "returns all field names" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      field_names = Schema.field_names(schema)

      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
      assert :inserted_at in field_names
      assert :updated_at in field_names
    end
  end

  describe "foreign_key_field_names/1" do
    test "returns foreign key field names" do
      schema = Schema.from_ecto_schema(TestSchemas.AssociationsSchema)

      fk_names = Schema.foreign_key_field_names(schema)

      assert fk_names == [:parent_id]
    end

    test "returns empty list when no foreign keys" do
      schema = Schema.from_ecto_schema(TestSchemas.UserSchema)

      fk_names = Schema.foreign_key_field_names(schema)

      assert fk_names == []
    end
  end
end
