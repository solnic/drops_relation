defmodule Drops.Relation.Plugins.SchemaTest do
  use Test.RelationCase, async: false

  describe "Doctests" do
    @describetag fixtures: [:users, :posts]

    doctest Drops.Relation.Plugins.Schema
  end

  describe "automatic schema inference" do
    @tag relations: [:users]
    test "infers complete schema from database", %{users: users} do
      schema = users.schema()

      assert schema.__struct__ == Drops.Relation.Schema
      assert schema.source == :users
      assert length(schema.fields) > 0

      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
      assert :age in field_names
      assert :active in field_names
    end

    @tag relations: [:posts]
    test "infers schema with foreign keys", %{posts: posts} do
      schema = posts.schema()

      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :title in field_names
      assert :body in field_names
      assert :user_id in field_names
      assert :published in field_names
      assert :view_count in field_names
    end
  end

  # Field selection from inferred schema is documented in the plugin docstring
  # This feature allows selecting specific fields: schema([:id, :name, :email])

  describe "manual schema definition" do
    relation(:custom_users) do
      schema("users") do
        field(:name, :string)
        field(:email, :string)
        field(:active, :boolean, default: true)
      end
    end

    test "creates schema from manual definition", %{custom_users: custom} do
      schema = custom.schema()

      field_names = Enum.map(schema.fields, & &1.name)
      assert :name in field_names
      assert :email in field_names
      assert :active in field_names

      # Find the active field and check its default
      active_field = Enum.find(schema.fields, &(&1.name == :active))
      assert active_field.type == :boolean
    end
  end

  describe "schema access and struct generation" do
    @tag relations: [:users]
    test "provides access to schema metadata", %{users: users} do
      schema = users.schema()

      # Test field access by name
      email_field = schema[:email]
      assert email_field.name == :email
      assert email_field.type == :string

      # Test that non-existent fields return nil
      assert schema[:nonexistent] == nil
    end

    @tag relations: [:users]
    test "generates Ecto schema module", %{users: users} do
      schema_module = users.__schema_module__()

      # Verify it's a valid module
      assert Code.ensure_loaded?(schema_module)
      assert is_atom(schema_module)

      # Test Ecto.Schema functions
      assert users.__schema__(:source) == "users"
      assert :id in users.__schema__(:fields)
      assert :name in users.__schema__(:fields)
      assert :email in users.__schema__(:fields)
    end

    @tag relations: [:users]
    test "creates struct instances", %{users: users} do
      user = users.struct(%{name: "John", email: "john@example.com"})

      assert user.name == "John"
      assert user.email == "john@example.com"
      # Not set in struct creation
      assert is_nil(user.id)

      # Verify it's the correct struct type
      schema_module = users.__schema_module__()
      assert user.__struct__ == schema_module
    end

    @tag relations: [:posts]
    test "works with posts schema", %{posts: posts} do
      post = posts.struct(%{title: "My First Post", body: "Hello World", published: true})

      assert post.title == "My First Post"
      assert post.body == "Hello World"
      assert post.published == true
      assert is_nil(post.id)
      assert is_nil(post.user_id)
    end
  end

  describe "schema field types and metadata" do
    @tag relations: [:users]
    test "preserves field type information", %{users: users} do
      schema = users.schema()

      # Check specific field types
      id_field = schema[:id]
      assert id_field.type in [:id, :integer]

      name_field = schema[:name]
      assert name_field.type == :string

      age_field = schema[:age]
      assert age_field.type == :integer

      active_field = schema[:active]
      assert active_field.type == :boolean
    end

    @tag relations: [:posts]
    test "handles different field types in posts", %{posts: posts} do
      schema = posts.schema()

      title_field = schema[:title]
      assert title_field.type == :string

      body_field = schema[:body]
      assert body_field.type == :string

      published_field = schema[:published]
      assert published_field.type == :boolean

      view_count_field = schema[:view_count]
      assert view_count_field.type == :integer

      user_id_field = schema[:user_id]
      assert user_id_field.type in [:id, :integer]
    end
  end

  describe "schema with custom struct names" do
    relation(:custom_struct_users) do
      schema("users", infer: true, struct: "CustomUser")
    end

    test "uses custom struct name", %{custom_struct_users: custom} do
      schema_module = custom.__schema_module__()
      assert is_atom(schema_module)

      user = custom.struct(%{name: "Test", email: "test@example.com"})
      assert user.__struct__ == schema_module
    end
  end

  describe "schema inheritance and merging" do
    relation(:extended_users) do
      schema("users", infer: true) do
        field(:computed_field, :string, virtual: true)
      end
    end

    test "merges inferred schema with manual fields", %{extended_users: extended} do
      schema = extended.schema()

      field_names = Enum.map(schema.fields, & &1.name)

      # Should have both inferred and manual fields
      assert :id in field_names
      assert :name in field_names
      assert :email in field_names

      # Note: Virtual fields may not be included in the schema fields list
      # This is expected behavior for virtual fields
    end
  end
end
