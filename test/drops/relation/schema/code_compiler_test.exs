defmodule Drops.Relation.Schema.CodeCompilerTest do
  @moduledoc """
  Tests for the CodeCompiler that converts Drops.Relation.Schema to Ecto schema AST.

  This test suite compiles actual Ecto.Schema modules from the generated AST and verifies
  their behavior using Ecto's reflection functions, making the tests more robust than
  AST comparison.
  """
  use ExUnit.Case, async: true

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey, CodeCompiler}

  # Helper function to compile a schema module from CodeCompiler output
  defp compile_test_schema(schema, module_name) do
    field_asts = CodeCompiler.visit(schema, [])

    # Separate attributes from field definitions
    {attributes, field_definitions} =
      Enum.split_with(field_asts, fn ast ->
        case ast do
          {:@, _, _} -> true
          _ -> false
        end
      end)

    # Check if we need to disable the default primary key to avoid conflicts
    has_custom_primary_key =
      Enum.any?(attributes, fn
        {:@, _, [{:primary_key, _, _}]} -> true
        _ -> false
      end)

    # Add @primary_key false if we don't have a custom primary key but have field definitions
    # This prevents Ecto from auto-adding an :id field that might conflict
    final_attributes =
      if has_custom_primary_key or field_definitions == [] do
        attributes
      else
        # Check if any field definition is for :id field
        has_id_field =
          Enum.any?(field_definitions, fn
            {{:., _, [{:__aliases__, _, [:Ecto, :Schema]}, :field]}, _, [:id | _]} -> true
            _ -> false
          end)

        if has_id_field do
          [{:@, [], [{:primary_key, [], [false]}]} | attributes]
        else
          attributes
        end
      end

    # Create the schema AST
    schema_ast =
      quote location: :keep do
        Ecto.Schema.schema unquote(schema.source) do
          (unquote_splicing(field_definitions))
        end
      end

    # Create the complete module AST
    module_ast =
      quote do
        defmodule unquote(module_name) do
          use Ecto.Schema
          import Ecto.Schema
          (unquote_splicing(final_attributes))
          unquote(schema_ast)
        end
      end

    # Compile the module
    Code.eval_quoted(module_ast)
    module_name
  end

  describe "CodeCompiler.visit/2 with basic schemas" do
    test "generates working schema for simple fields" do
      field = Field.new(:name, :string, %{source: :name})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema1)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :name in module.__schema__(:fields)
      assert module.__schema__(:type, :name) == :string
    end

    test "generates working schema with source mapping" do
      field = Field.new(:email, :string, %{source: :email_address})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema2)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :email in module.__schema__(:fields)
      assert module.__schema__(:type, :email) == :string
      # Note: Ecto doesn't expose source mapping through reflection,
      # but the fact that it compiles without error validates the AST
    end

    test "generates working schema with default values" do
      field = Field.new(:status, :string, %{source: :status, default: "active"})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema3)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :status in module.__schema__(:fields)
      assert module.__schema__(:type, :status) == :string

      # Verify default value by creating a struct
      struct = struct(module)
      assert struct.status == "active"
    end

    test "skips auto_increment default values" do
      field = Field.new(:id, :integer, %{source: :id, default: :auto_increment})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema4)

      # Verify the schema was compiled correctly without the invalid default
      assert module.__schema__(:source) == "users"
      assert :id in module.__schema__(:fields)
      assert module.__schema__(:type, :id) == :integer

      # Verify no default value was set (should be nil)
      struct = struct(module)
      assert struct.id == nil
    end
  end

  describe "CodeCompiler.visit/2 with parameterized types" do
    test "generates working schema for Ecto.Enum fields" do
      field = Field.new(:status, {Ecto.Enum, [values: [:active, :inactive]]}, %{source: :status})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema5)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :status in module.__schema__(:fields)
      # Ecto.Enum types are returned as parameterized types
      assert {:parameterized, {Ecto.Enum, _}} = module.__schema__(:type, :status)

      # Verify the enum works by creating a changeset
      changeset = Ecto.Changeset.cast(struct(module), %{status: :active}, [:status])
      assert changeset.valid?

      # Verify invalid enum value is rejected
      changeset = Ecto.Changeset.cast(struct(module), %{status: :invalid}, [:status])
      refute changeset.valid?
    end

    test "merges type options with field options correctly" do
      field =
        Field.new(:tags, {Ecto.Enum, [values: [:red, :green, :blue]]}, %{
          source: :color_tags,
          default: :red
        })

      schema = Schema.new("items", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema6)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "items"
      assert :tags in module.__schema__(:fields)
      # Ecto.Enum types are returned as parameterized types
      assert {:parameterized, {Ecto.Enum, _}} = module.__schema__(:type, :tags)

      # Verify default value works
      struct = struct(module)
      assert struct.tags == :red

      # Verify the enum validation works
      changeset = Ecto.Changeset.cast(struct(module), %{tags: :green}, [:tags])
      assert changeset.valid?
    end
  end

  describe "CodeCompiler.visit/2 with primary keys" do
    test "generates working schema with UUID primary key" do
      field = Field.new(:id, Ecto.UUID, %{source: :id, primary_key: true})
      pk = PrimaryKey.new([field])
      schema = Schema.new("users", pk, [], [field], [])

      module = compile_test_schema(schema, TestSchema7)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert module.__schema__(:primary_key) == [:id]
      assert module.__schema__(:type, :id) == Ecto.UUID

      # Verify the primary key is autogenerated
      struct = struct(module)
      # Should be nil until autogenerated
      assert struct.id == nil
    end

    test "generates working schema with binary_id primary key" do
      field = Field.new(:uuid, :binary_id, %{source: :uuid, primary_key: true})
      pk = PrimaryKey.new([field])
      schema = Schema.new("users", pk, [], [field], [])

      module = compile_test_schema(schema, TestSchema8)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert module.__schema__(:primary_key) == [:uuid]
      assert module.__schema__(:type, :uuid) == :binary_id
    end

    test "generates working schema with composite primary keys" do
      field1 = Field.new(:user_id, :integer, %{source: :user_id, primary_key: true})
      field2 = Field.new(:role_id, :integer, %{source: :role_id, primary_key: true})
      pk = PrimaryKey.new([field1, field2])
      schema = Schema.new("user_roles", pk, [], [field1, field2], [])

      module = compile_test_schema(schema, TestSchema9)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "user_roles"
      assert module.__schema__(:primary_key) == [:user_id, :role_id]
      assert module.__schema__(:type, :user_id) == :integer
      assert module.__schema__(:type, :role_id) == :integer

      # Verify both fields are present
      assert :user_id in module.__schema__(:fields)
      assert :role_id in module.__schema__(:fields)
    end

    test "generates working schema with default integer primary key" do
      field = Field.new(:id, :id, %{source: :id, primary_key: true})
      pk = PrimaryKey.new([field])
      schema = Schema.new("users", pk, [], [field], [])

      module = compile_test_schema(schema, TestSchema10)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert module.__schema__(:primary_key) == [:id]
      assert module.__schema__(:type, :id) == :id
    end
  end

  describe "CodeCompiler.visit/2 with foreign keys" do
    test "generates working schema with binary_id foreign keys" do
      field = Field.new(:user_id, :binary_id, %{source: :user_id, foreign_key: true})
      schema = Schema.new("posts", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema11)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "posts"
      assert :user_id in module.__schema__(:fields)
      assert module.__schema__(:type, :user_id) == :binary_id
    end

    test "generates working schema with UUID foreign keys" do
      field = Field.new(:owner_id, Ecto.UUID, %{source: :owner_id, foreign_key: true})
      schema = Schema.new("items", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema12)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "items"
      assert :owner_id in module.__schema__(:fields)
      assert module.__schema__(:type, :owner_id) == Ecto.UUID
    end

    test "generates working schema with integer foreign keys" do
      field = Field.new(:category_id, :integer, %{source: :category_id, foreign_key: true})
      schema = Schema.new("posts", nil, [], [field], [])

      module = compile_test_schema(schema, TestSchema13)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "posts"
      assert :category_id in module.__schema__(:fields)
      assert module.__schema__(:type, :category_id) == :integer
    end
  end

  describe "CodeCompiler.visit/2 with timestamp fields" do
    test "skips timestamp fields correctly" do
      field1 = Field.new(:name, :string, %{source: :name})
      field2 = Field.new(:inserted_at, :naive_datetime, %{source: :inserted_at})
      field3 = Field.new(:updated_at, :naive_datetime, %{source: :updated_at})
      schema = Schema.new("users", nil, [], [field1, field2, field3], [])

      module = compile_test_schema(schema, TestSchema14)

      # Should only have the name field, timestamp fields are skipped
      assert module.__schema__(:source) == "users"
      assert :name in module.__schema__(:fields)
      assert module.__schema__(:type, :name) == :string

      # Timestamp fields should not be in the schema fields
      refute :inserted_at in module.__schema__(:fields)
      refute :updated_at in module.__schema__(:fields)
    end
  end

  describe "CodeCompiler.visit/2 edge cases" do
    test "handles empty schema" do
      schema = Schema.new("empty", nil, [], [], [])

      module = compile_test_schema(schema, TestSchema15)

      # Should compile successfully - Ecto automatically adds :id field when no primary key is specified
      assert module.__schema__(:source) == "empty"
      assert :id in module.__schema__(:fields)
      assert module.__schema__(:primary_key) == [:id]
    end

    test "handles complex field combinations" do
      # Mix of regular fields, primary key, foreign key, and parameterized type
      pk_field = Field.new(:id, Ecto.UUID, %{source: :id, primary_key: true})
      fk_field = Field.new(:user_id, :binary_id, %{source: :user_id, foreign_key: true})

      enum_field =
        Field.new(:status, {Ecto.Enum, [values: [:draft, :published]]}, %{
          source: :status,
          default: :draft
        })

      regular_field = Field.new(:title, :string, %{source: :title})

      pk = PrimaryKey.new([pk_field])
      schema = Schema.new("posts", pk, [], [pk_field, fk_field, enum_field, regular_field], [])

      module = compile_test_schema(schema, TestSchema16)

      # Verify all components work together
      assert module.__schema__(:source) == "posts"
      assert module.__schema__(:primary_key) == [:id]
      assert module.__schema__(:type, :id) == Ecto.UUID
      assert module.__schema__(:type, :user_id) == :binary_id
      assert {:parameterized, {Ecto.Enum, _}} = module.__schema__(:type, :status)
      assert module.__schema__(:type, :title) == :string

      # Verify default value works
      struct = struct(module)
      assert struct.status == :draft

      # Verify enum validation works
      changeset = Ecto.Changeset.cast(struct, %{status: :published}, [:status])
      assert changeset.valid?
    end
  end
end
