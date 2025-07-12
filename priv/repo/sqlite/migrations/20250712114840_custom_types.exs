defmodule Drops.Relation.Repos.Sqlite.Migrations.CustomTypes20250712114840 do
  use Ecto.Migration

  def change do
    create table(:custom_types) do
      # SQLite-specific type mappings
      add :blob_field, :blob        # SQLite BLOB type
      add :real_field, :real        # SQLite REAL type
      add :numeric_field, :decimal  # SQLite NUMERIC type

      # SQLite boolean (stored as INTEGER)
      add :boolean_field, :boolean
      add :boolean_false_default, :boolean, default: false
      add :boolean_true_default, :boolean, default: true

      # SQLite date/time types (stored as TEXT)
      add :date_field, :date
      add :time_field, :time
      add :datetime_field, :naive_datetime

      # SQLite with various defaults
      add :integer_zero_default, :integer, default: 0
      add :integer_one_default, :integer, default: 1
      add :text_with_default, :string, default: "sqlite_default"

      # SQLite precision types (stored as TEXT/NUMERIC)
      add :decimal_field, :decimal
      add :float_field, :float
      add :double_field, :float  # SQLite treats DOUBLE as REAL

      # SQLite string variations (all stored as TEXT)
      add :varchar_field, :string
      add :char_field, :string
      add :clob_field, :string

      # SQLite JSON (stored as TEXT, interpreted as map)
      add :json_field, :map

      # SQLite constraints
      add :required_text, :string, null: false
      add :optional_text, :string, null: true

      # SQLite with check constraints (will be added via raw SQL if needed)
      add :score_field, :integer  # Can add CHECK constraint separately

      timestamps()
    end

    # SQLite doesn't support adding constraints after table creation
    # The check constraint would need to be added during table creation
  end
end
