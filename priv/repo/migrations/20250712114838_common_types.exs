defmodule Drops.Relation.Repos.CommonTypes do
  use Ecto.Migration

  def change do
    create table(:common_types) do
      # Basic types that work similarly in both PostgreSQL and SQLite
      add :string_field, :string
      add :integer_field, :integer
      add :text_field, :text
      add :binary_field, :binary

      # Types with defaults (only truly common ones)
      add :string_with_default, :string, default: "default_value"
      add :integer_with_default, :integer, default: 42

      # Nullable vs non-nullable
      add :required_string, :string, null: false
      add :optional_string, :string, null: true

      timestamps()
    end
  end
end
