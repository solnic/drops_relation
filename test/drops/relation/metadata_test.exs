defmodule Drops.Relation.MetadataIntegrationTest do
  use Drops.RelationCase, async: false

  describe "metadata integration with field inference" do
    @describetag relations: [:metadata_test], adapter: :sqlite

    test "inferred fields include metadata from database introspection", %{
      metadata_test: relation
    } do
      schema = relation.schema()

      status_field = schema[:status]
      description_field = schema[:description]
      score_field = schema[:score]

      assert status_field.meta.nullable == false
      assert status_field.meta.default == "active"

      assert description_field.meta.nullable == true

      assert score_field.meta.nullable == false
      assert is_list(score_field.meta.check_constraints)
    end
  end

  describe "parameterized types with metadata" do
    relation(:metadata_test) do
      schema("metadata_test") do
        field(:status, Ecto.Enum, values: [:active, :inactive, :pending])
        field(:priority, :integer, default: 10)
      end
    end

    test "Ecto.Enum fields work with inferred metadata", %{metadata_test: relation} do
      # This tests the end-to-end flow that was previously failing
      # Should compile without errors
      assert relation.ecto_schema(:fields) != nil

      # Check that the custom field types are respected
      status_type = relation.ecto_schema(:type, :status)
      assert match?({:parameterized, {Ecto.Enum, _}}, status_type)

      priority_type = relation.ecto_schema(:type, :priority)
      assert priority_type == :integer

      # Check that inferred fields are still present
      fields = relation.ecto_schema(:fields)
      assert :name in fields
      assert :description in fields
      assert :score in fields
    end
  end
end
