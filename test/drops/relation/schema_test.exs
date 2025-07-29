defmodule Drops.Relation.SchemaTest do
  use Test.RelationCase, async: false

  describe "merge/2" do
    @describetag adapter: :sqlite

    relation(:metadata_test) do
      schema("metadata_test", infer: true) do
        field(:status, Ecto.Enum, values: [:active, :inactive, :pending])
        field(:priority, :integer, default: 10)
      end
    end

    test "merging field type and meta", %{metadata_test: relation} do
      schema = relation.schema()

      status_field = schema[:status]
      priority_field = schema[:priority]

      assert {:parameterized, {Ecto.Enum, _}} = status_field.type
      assert priority_field.meta.default == 10
    end
  end
end
