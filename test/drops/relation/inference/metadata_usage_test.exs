defmodule Drops.Relation.Inference.MetadataUsageTest do
  @moduledoc """
  Tests to verify that database inference uses metadata (primary_key: true/false, foreign_key: true/false)
  instead of relying on field name patterns like "_id" or "id".

  This ensures the system is robust and doesn't make assumptions based on naming conventions.
  """
  use ExUnit.Case, async: true

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey}
  alias Drops.Relation.Schema.CodeCompiler

  describe "CodeCompiler uses metadata instead of field names" do
    test "generates primary key attribute based on metadata, not field name" do
      # Create a field with a non-standard primary key name but proper metadata
      meta = %{primary_key: true}
      field = Field.new(:uuid_identifier, :binary_id, meta)
      pk = PrimaryKey.new([field])

      schema = Schema.new("test_table", pk, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should generate @primary_key attribute based on metadata, not field name
      assert [attr_ast] = result
      assert {:@, _, [{:primary_key, _, [tuple_ast]}]} = attr_ast
      assert {:{}, _, [:uuid_identifier, :binary_id, [autogenerate: true]]} = tuple_ast
    end

    test "generates foreign key attribute based on metadata, not field name" do
      # Create a field with a non-standard foreign key name but proper metadata
      meta = %{foreign_key: true}
      field = Field.new(:owner_reference, :binary_id, meta)

      schema = Schema.new("test_table", nil, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should generate @foreign_key_type attribute based on metadata, not field name
      assert [attr_ast, _field_ast] = result
      assert {:@, _, [{:foreign_key_type, _, [:binary_id]}]} = attr_ast
    end

    test "does not generate primary key attribute for field named 'id' without metadata" do
      # Create a field named 'id' but without primary_key metadata
      meta = %{primary_key: false}
      field = Field.new(:id, :binary_id, meta)

      schema = Schema.new("test_table", nil, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should NOT generate @primary_key attribute since metadata says it's not a primary key
      # Should only generate field definition
      assert [field_ast] = result

      assert {{:., _, [{:__aliases__, _, [:Ecto, :Schema]}, :field]}, _, [:id, :binary_id]} =
               field_ast
    end

    test "does not generate foreign key attribute for field ending in '_id' without metadata" do
      # Create a field with typical foreign key naming but without foreign_key metadata
      meta = %{foreign_key: false}
      field = Field.new(:user_id, :binary_id, meta)

      schema = Schema.new("test_table", nil, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should NOT generate @foreign_key_type attribute since metadata says it's not a foreign key
      # Should only generate field definition
      assert [field_ast] = result

      assert {{:., _, [{:__aliases__, _, [:Ecto, :Schema]}, :field]}, _, [:user_id, :binary_id]} =
               field_ast
    end

    test "handles UUID primary key with non-standard name" do
      # Create a UUID primary key field with non-standard name
      meta = %{primary_key: true}
      field = Field.new(:entity_uuid, Ecto.UUID, meta)
      pk = PrimaryKey.new([field])

      schema = Schema.new("test_table", pk, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should generate @primary_key attribute for UUID type
      assert [attr_ast] = result
      assert {:@, _, [{:primary_key, _, [tuple_ast]}]} = attr_ast

      assert {:{}, _, [:entity_uuid, {:__aliases__, _, [:Ecto, :UUID]}, [autogenerate: true]]} =
               tuple_ast
    end

    test "handles UUID foreign key with non-standard name" do
      # Create a UUID foreign key field with non-standard name
      meta = %{foreign_key: true}
      field = Field.new(:parent_entity, Ecto.UUID, meta)

      schema = Schema.new("test_table", nil, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should generate @foreign_key_type attribute for UUID foreign key
      assert [attr_ast, _field_ast] = result
      assert {:@, _, [{:foreign_key_type, _, [:binary_id]}]} = attr_ast
    end

    test "regular field with standard naming does not generate attributes" do
      # Create a regular field that happens to end in '_id' but is not a foreign key
      meta = %{primary_key: false, foreign_key: false}
      field = Field.new(:external_id, :string, meta)

      schema = Schema.new("test_table", nil, [], [field], [])

      result = CodeCompiler.visit(schema, [])

      # Should not generate any attribute since it's just a regular field
      # Should only generate field definition
      assert [field_ast] = result

      assert {{:., _, [{:__aliases__, _, [:Ecto, :Schema]}, :field]}, _, [:external_id, :string]} =
               field_ast
    end
  end

  describe "Field metadata structure" do
    test "Field.new/5 accepts metadata with primary_key and foreign_key keys" do
      meta = %{
        nullable: false,
        default: nil,
        check_constraints: [],
        primary_key: true,
        foreign_key: false
      }

      field = Field.new(:test_field, :integer, :id, :test_field, meta)

      assert field.meta.primary_key == true
      assert field.meta.foreign_key == false
      assert field.meta.nullable == false
    end

    test "Field metadata defaults work correctly" do
      field = Field.new(:test_field, :string, :string, :test_field)

      assert field.meta == %{source: :test_field, type: :string}

      assert Map.get(field.meta, :primary_key, false) == false
      assert Map.get(field.meta, :foreign_key, false) == false
    end
  end
end
