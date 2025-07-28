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

      active_field = Enum.find(schema.fields, &(&1.name == :active))
      assert active_field.type == :boolean
    end
  end

  describe "schema access and struct generation" do
    @tag relations: [:users]
    test "provides access to schema metadata", %{users: users} do
      schema = users.schema()

      email_field = schema[:email]
      assert email_field.name == :email
      assert email_field.type == :string

      assert schema[:nonexistent] == nil
    end

    @tag relations: [:users]
    test "generates Ecto schema module", %{users: users} do
      schema_module = users.__schema_module__()

      assert Code.ensure_loaded?(schema_module)
      assert is_atom(schema_module)

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
      assert is_nil(user.id)

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

      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
    end
  end

  describe "embeds support" do
    defmodule TestEmbedded do
      use Ecto.Schema

      embedded_schema do
        field(:name, :string)
        field(:value, :integer)
      end
    end

    relation(:users_with_embeds) do
      schema("users") do
        field(:name, :string)
        embeds_one(:metadata, TestEmbedded)
        embeds_many(:tags, TestEmbedded)
      end
    end

    test "handles embeds_one and embeds_many in schema blocks", %{users_with_embeds: users} do
      schema = users.schema()

      field_names = Enum.map(schema.fields, & &1.name)
      assert :name in field_names
      assert :metadata in field_names
      assert :tags in field_names

      metadata_field = schema[:metadata]
      assert metadata_field.meta[:embed] == true
      assert metadata_field.meta[:embed_cardinality] == :one
      assert to_string(metadata_field.meta[:embed_related]) =~ "TestEmbedded"

      tags_field = schema[:tags]
      assert tags_field.meta[:embed] == true
      assert tags_field.meta[:embed_cardinality] == :many
      assert to_string(tags_field.meta[:embed_related]) =~ "TestEmbedded"
    end

    test "generates correct Ecto schema with embeds", %{users_with_embeds: users} do
      schema_module = users.__schema_module__()

      assert :metadata in schema_module.__schema__(:embeds)
      assert :tags in schema_module.__schema__(:embeds)

      metadata_embed = schema_module.__schema__(:embed, :metadata)
      assert metadata_embed.cardinality == :one
      assert to_string(metadata_embed.related) =~ "TestEmbedded"

      tags_embed = schema_module.__schema__(:embed, :tags)
      assert tags_embed.cardinality == :many
      assert to_string(tags_embed.related) =~ "TestEmbedded"
    end

    test "creates struct instances with embeds", %{users_with_embeds: users} do
      user =
        users.struct(%{
          name: "John",
          metadata: %{name: "test", value: 42},
          tags: [%{name: "tag1", value: 1}, %{name: "tag2", value: 2}]
        })

      assert user.name == "John"
      assert user.metadata.name == "test"
      assert user.metadata.value == 42
      assert length(user.tags) == 2
      assert hd(user.tags).name == "tag1"
    end
  end

  describe "embeds with inline schemas" do
    relation(:users_with_inline_embeds) do
      schema("users") do
        field(:name, :string)

        embeds_one :profile, Profile do
          field(:bio, :string)
          field(:age, :integer)
        end

        embeds_many :addresses, Address do
          field(:street, :string)
          field(:city, :string)
        end
      end
    end

    test "handles inline embedded schemas", %{users_with_inline_embeds: users} do
      schema = users.schema()

      field_names = Enum.map(schema.fields, & &1.name)
      assert :name in field_names
      assert :profile in field_names
      assert :addresses in field_names

      profile_field = schema[:profile]
      assert profile_field.meta[:embed] == true
      assert profile_field.meta[:embed_cardinality] == :one

      addresses_field = schema[:addresses]
      assert addresses_field.meta[:embed] == true
      assert addresses_field.meta[:embed_cardinality] == :many
    end

    test "generates correct Ecto schema with inline embeds", %{users_with_inline_embeds: users} do
      schema_module = users.__schema_module__()

      assert :profile in schema_module.__schema__(:embeds)
      assert :addresses in schema_module.__schema__(:embeds)

      profile_embed = schema_module.__schema__(:embed, :profile)
      assert profile_embed.cardinality == :one

      addresses_embed = schema_module.__schema__(:embed, :addresses)
      assert addresses_embed.cardinality == :many
    end
  end

  describe "embeds integration with schema merging" do
    relation(:users_with_mixed_embeds) do
      schema("users", infer: true) do
        embeds_one(:profile, TestEmbedded)
        embeds_many(:preferences, TestEmbedded)
      end
    end

    test "merges inferred schema with embed definitions", %{users_with_mixed_embeds: users} do
      schema = users.schema()

      field_names = Enum.map(schema.fields, & &1.name)

      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
      assert :profile in field_names
      assert :preferences in field_names

      profile_field = schema[:profile]
      assert profile_field.meta[:embed] == true
      assert profile_field.meta[:embed_cardinality] == :one

      preferences_field = schema[:preferences]
      assert preferences_field.meta[:embed] == true
      assert preferences_field.meta[:embed_cardinality] == :many

      name_field = schema[:name]
      assert name_field.meta[:embed] == false
    end

    test "generates correct mixed schema", %{users_with_mixed_embeds: users} do
      schema_module = users.__schema_module__()

      assert :name in schema_module.__schema__(:fields)
      assert :email in schema_module.__schema__(:fields)
      assert :profile in schema_module.__schema__(:fields)
      assert :preferences in schema_module.__schema__(:fields)

      assert :profile in schema_module.__schema__(:embeds)
      assert :preferences in schema_module.__schema__(:embeds)

      user =
        users.struct(%{
          name: "John",
          email: "john@example.com",
          profile: %{name: "profile", value: 1},
          preferences: [%{name: "pref1", value: 1}]
        })

      assert user.name == "John"
      assert user.email == "john@example.com"
      assert user.profile.name == "profile"
      assert length(user.preferences) == 1
    end
  end
end
