defmodule Drops.Relation.Repos.Sqlite.Migrations.CreateComprehensiveTypesTables do
  use Ecto.Migration

  def change do
    # SQLite-specific types table
    create table(:type_mapping_tests) do
      # Core SQLite types
      add(:integer_type, :integer)
      add(:real_type, :real)
      add(:text_type, :text)
      add(:blob_type, :blob)
      # SQLite NUMERIC -> Ecto decimal
      add(:numeric_type, :decimal)

      # SQLite interpreted types (stored as other types but interpreted)
      # Stored as INTEGER 0/1
      add(:boolean_type, :boolean, default: true)
      # Stored as TEXT in ISO 8601
      add(:date_type, :date)
      # Stored as TEXT
      add(:datetime_type, :naive_datetime)
      # Stored as TEXT
      add(:timestamp_type, :naive_datetime)
      # Stored as TEXT
      add(:time_type, :time)
      # DECIMAL(10,2) -> TEXT
      add(:decimal_precision_type, :decimal)
      # FLOAT -> REAL
      add(:float_type, :float)
      # DOUBLE -> REAL
      add(:double_type, :float)
      # VARCHAR(255) -> TEXT
      add(:varchar_type, :string)
      # CHAR(10) -> TEXT
      add(:char_type, :string)
      # CLOB -> TEXT
      add(:clob_type, :string)
      # JSON -> TEXT (interpreted as map)
      add(:json_type, :map)

      timestamps()
    end

    create table(:special_cases) do
      # Test foreign key detection
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:parent_id, references(:special_cases, on_delete: :delete_all))

      # Test nullable vs non-nullable
      add(:required_field, :string, null: false)
      add(:optional_field, :string, null: true)

      # Test default values
      add(:default_string, :string, default: "default_value")
      add(:default_integer, :integer, default: 42)
      add(:default_boolean, :boolean, default: true)

      timestamps()
    end

    # Create indices for testing index introspection
    create(index(:type_mapping_tests, [:integer_type]))
    create(unique_index(:type_mapping_tests, [:text_type]))
    create(index(:type_mapping_tests, [:boolean_type, :date_type]))

    create(index(:special_cases, [:user_id]))
    create(unique_index(:special_cases, [:required_field]))
  end
end
