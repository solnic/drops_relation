defmodule Drops.Relation.Compilers.PostgresSchemaCompilerTest do
  use Drops.RelationCase, async: false

  describe "common types table" do
    @describetag relations: [:common_types], adapter: :postgres

    test "jsonb columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :jsonb_field, :map, default: nil)
      assert_field(schema, :jsonb_with_empty_map_default, :map, default: %{})
      assert_field(schema, :jsonb_with_empty_list_default, {:array, :any}, default: [])
    end

    test "map columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :map_field, :map, default: nil)
      assert_field(schema, :map_with_default, :map, type: :jsonb, default: %{})
    end

    test "array columns", %{common_types: relation} do
      schema = relation.schema()

      assert_field(schema, :array_with_string_member_field, {:array, :string},
        type: {:array, :string},
        default: nil
      )

      assert_field(schema, :array_with_string_member_and_default, {:array, :string}, default: [])

      assert_field(schema, :array_with_jsonb_member_field, {:array, :map},
        type: {:array, :jsonb},
        default: nil
      )

      assert_field(schema, :array_with_jsonb_member_and_default, {:array, :map},
        type: {:array, :jsonb},
        default: []
      )
    end
  end
end
