defmodule Test.Repos.CommonTypes do
  use Ecto.Migration

  def change do
    create table(:common_types) do
      # Basic types that work similarly in both PostgreSQL and SQLite
      add(:string_field, :string)
      add(:integer_field, :integer)
      add(:text_field, :text)
      add(:binary_field, :binary)

      # Arrays
      add(:array_with_string_member_field, {:array, :string})
      add(:array_with_string_member_and_default, {:array, :string}, default: [])

      add(:array_with_jsonb_member_field, {:array, :jsonb})
      add(:array_with_jsonb_member_and_default, {:array, :jsonb}, default: [])

      # Maps
      add(:map_field, :map)
      add(:map_with_default, :map, default: %{})

      # JSONB
      add(:jsonb_field, :jsonb)

      # JSONB with defaults
      add(:jsonb_with_empty_map_default, :jsonb, default: "{}")
      add(:jsonb_with_empty_list_default, :jsonb, default: "[]")

      # Types with defaults (only truly common ones)
      add(:string_with_default, :string, default: "default_value")
      add(:integer_with_default, :integer, default: 42)

      # Nullable vs non-nullable
      add(:required_string, :string, null: false)
      add(:optional_string, :string, null: true)

      timestamps()
    end
  end
end
