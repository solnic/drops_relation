defmodule Drops.Relation.Compilers.SqliteSchemaCompilerTest do
  use Drops.RelationCase, async: false

  describe "common types table" do
    @describetag relations: [:common_types], adapter: :sqlite

    test "jsonb columns", %{common_types: relation} do
      schema = relation.schema()

      field = schema[:jsonb_field]
      assert field.type == :map
      assert field.meta.default == nil

      field = schema[:jsonb_with_empty_map_default]
      assert field.type == :map
      assert field.meta.default == %{}

      field = schema[:jsonb_with_empty_list_default]
      assert field.type == {:array, :any}
      assert field.meta.default == []
    end

    test "map columns", %{common_types: relation} do
      schema = relation.schema()

      field = schema[:map_field]
      assert field.type == :string
      assert field.meta.default == nil

      field = schema[:map_with_default]
      assert field.type == :map
      assert field.meta.type == :string
      assert field.meta.default == %{}
    end

    test "array columns", %{common_types: relation} do
      schema = relation.schema()

      field = schema[:array_with_string_member_field]
      assert field.type == :string
      assert field.meta.type == :string
      assert field.meta.default == nil

      field = schema[:array_with_string_member_and_default]
      assert field.type == {:array, :any}
      assert field.meta.type == :string
      assert field.meta.default == []
    end
  end
end
