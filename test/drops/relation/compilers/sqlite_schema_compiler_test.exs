defmodule Drops.Relation.Compilers.SqliteSchemaCompilerTest do
  use Drops.RelationCase, async: false

  describe "common types table" do
    @describetag relations: [:common_types], adapter: :sqlite

    test "jsonb columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :jsonb_field, :map, type: :jsonb, default: nil)
      assert_field(schema, :jsonb_with_empty_map_default, :map, default: %{})
      assert_field(schema, :jsonb_with_empty_list_default, {:array, :any}, default: [])
    end

    test "map columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :map_field, :string, default: nil)
      assert_field(schema, :map_with_default, :map, type: :string, default: %{})
    end

    test "array columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :array_with_string_member_field, :string, type: :string, default: nil)

      assert_field(schema, :array_with_string_member_and_default, {:array, :any},
        type: :string,
        default: []
      )
    end
  end
end
