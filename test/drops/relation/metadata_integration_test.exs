defmodule Drops.Relation.MetadataIntegrationTest do
  use Drops.RelationCase, async: false

  alias Drops.Relation.Inference

  describe "metadata integration with field inference" do
    @describetag adapter: :sqlite

    test "inferred fields include metadata from database introspection" do
      schema = Inference.infer_schema("metadata_test", Drops.Relation.Repos.Sqlite)

      # Find specific fields
      status_field = Enum.find(schema.fields, &(&1.name == :status))
      description_field = Enum.find(schema.fields, &(&1.name == :description))
      score_field = Enum.find(schema.fields, &(&1.name == :score))

      # Test that metadata is properly extracted
      assert status_field.meta.nullable == false
      assert status_field.meta.default == "active"

      assert description_field.meta.nullable == true

      assert score_field.meta.nullable == false
      assert is_list(score_field.meta.check_constraints)
    end
  end

  describe "parameterized types with metadata" do
    @describetag adapter: :sqlite

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

  describe "Field.merge behavior in practice" do
    @describetag adapter: :sqlite

    test "custom field options override inferred metadata appropriately" do
      # Get an inferred field with metadata
      schema = Inference.infer_schema("metadata_test", Drops.Relation.Repos.Sqlite)
      status_field = Enum.find(schema.fields, &(&1.name == :status))

      # Create a custom field that overrides some properties
      # Override both
      custom_meta = %{nullable: true, default: "pending"}

      custom_field =
        Drops.Relation.Schema.Field.new(
          :status,
          {Ecto.Enum, values: [:active, :inactive, :pending]},
          custom_meta
        )

      # Merge them
      merged = Drops.Relation.Schema.Field.merge(status_field, custom_field)

      # Custom field properties should take precedence
      assert merged.type == {Ecto.Enum, values: [:active, :inactive, :pending]}
      # overridden
      assert merged.meta.nullable == true
      # overridden
      assert merged.meta.default == "pending"

      # But check constraints from database should be preserved if not overridden
      if status_field.meta[:check_constraints] do
        assert merged.meta[:check_constraints] == status_field.meta[:check_constraints]
      end
    end
  end
end
