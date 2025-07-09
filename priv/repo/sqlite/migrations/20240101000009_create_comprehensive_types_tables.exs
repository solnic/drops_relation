defmodule Drops.Relation.Repos.Sqlite.Migrations.CreateComprehensiveTypesTables do
  use Ecto.Migration

  def change do
    # SQLite-specific types table
    create table(:type_mapping_tests) do
      # Core SQLite types
      add :integer_type, :integer
      add :real_type, :real
      add :text_type, :text
      add :blob_type, :blob
      add :numeric_type, :decimal  # SQLite NUMERIC -> Ecto decimal

      # SQLite interpreted types (stored as other types but interpreted)
      add :boolean_type, :boolean  # Stored as INTEGER 0/1
      add :date_type, :date        # Stored as TEXT in ISO 8601
      add :datetime_type, :naive_datetime  # Stored as TEXT
      add :timestamp_type, :naive_datetime # Stored as TEXT
      add :time_type, :time        # Stored as TEXT
      add :decimal_precision_type, :decimal # DECIMAL(10,2) -> TEXT
      add :float_type, :float      # FLOAT -> REAL
      add :double_type, :float     # DOUBLE -> REAL
      add :varchar_type, :string   # VARCHAR(255) -> TEXT
      add :char_type, :string      # CHAR(10) -> TEXT
      add :clob_type, :string      # CLOB -> TEXT
      add :json_type, :map         # JSON -> TEXT (interpreted as map)

      timestamps()
    end

    # PostgreSQL-specific types table
    create table(:postgres_types) do
      # Integer types with aliases
      add :smallint_type, :smallint
      add :int2_type, :smallint     # PostgreSQL alias
      add :integer_type, :integer
      add :int_type, :integer       # PostgreSQL alias
      add :int4_type, :integer      # PostgreSQL alias
      add :bigint_type, :bigint
      add :int8_type, :bigint       # PostgreSQL alias

      # Serial types
      add :serial_type, :serial
      add :bigserial_type, :bigserial

      # Floating point types
      add :real_type, :real
      add :float4_type, :real       # PostgreSQL alias
      add :double_precision_type, :float
      add :float8_type, :float      # PostgreSQL alias

      # Decimal types
      add :numeric_type, :decimal
      add :decimal_type, :decimal
      add :money_type, :decimal     # PostgreSQL money type

      # String types
      add :character_varying_type, :string
      add :varchar_type, :string
      add :character_type, :string
      add :char_type, :string
      add :text_type, :text
      add :name_type, :string       # PostgreSQL internal name type

      # Date/time types
      add :date_type, :date
      add :time_type, :time
      add :time_with_tz_type, :time
      add :timestamp_type, :naive_datetime
      add :timestamp_with_tz_type, :utc_datetime

      # Binary types
      add :bytea_type, :binary

      # Boolean type
      add :boolean_type, :boolean

      # JSON types
      add :json_type, :map
      add :jsonb_type, :map

      # UUID type
      add :uuid_type, :binary_id

      # Network types
      add :inet_type, :inet         # Will map to string for now
      add :cidr_type, :cidr         # Will map to string for now
      add :macaddr_type, :macaddr   # Will map to string for now

      # XML type
      add :xml_type, :text

      timestamps()
    end

    # PostgreSQL array types table
    create table(:postgres_array_types) do
      add :integer_array, {:array, :integer}
      add :text_array, {:array, :string}
      add :boolean_array, {:array, :boolean}
      add :uuid_array, {:array, :binary_id}

      timestamps()
    end

    # PostgreSQL geometric types table (these will need custom handling)
    create table(:postgres_geometric_types) do
      add :point_type, :string      # Will need custom type
      add :line_type, :string       # Will need custom type
      add :lseg_type, :string       # Will need custom type
      add :box_type, :string        # Will need custom type
      add :path_type, :string       # Will need custom type
      add :polygon_type, :string    # Will need custom type
      add :circle_type, :string     # Will need custom type

      timestamps()
    end

    # Special cases table for testing edge cases
    create table(:special_cases) do
      # Test foreign key detection
      add :user_id, references(:users, on_delete: :delete_all)
      add :parent_id, references(:special_cases, on_delete: :delete_all)

      # Test nullable vs non-nullable
      add :required_field, :string, null: false
      add :optional_field, :string, null: true

      # Test default values
      add :default_string, :string, default: "default_value"
      add :default_integer, :integer, default: 42
      add :default_boolean, :boolean, default: true

      timestamps()
    end

    # PostgreSQL serial type aliases table for testing type alias inference
    # Note: SQLite doesn't have serial types, but we create this for consistency
    create table(:postgres_serial_aliases) do
      add :serial4_id, :integer      # SQLite doesn't have serial, use integer
      add :serial8_id, :integer      # SQLite doesn't have bigserial, use integer
      add :serial2_id, :integer      # SQLite doesn't have smallserial, use integer
      add :regular_serial, :integer  # SQLite doesn't have serial, use integer
      add :regular_bigserial, :integer # SQLite doesn't have bigserial, use integer
      add :regular_smallserial, :integer # SQLite doesn't have smallserial, use integer
    end

    # Create indices for testing index introspection
    create index(:type_mapping_tests, [:integer_type])
    create unique_index(:type_mapping_tests, [:text_type])
    create index(:type_mapping_tests, [:boolean_type, :date_type])

    create index(:postgres_types, [:integer_type])
    create unique_index(:postgres_types, [:uuid_type])
    create index(:postgres_types, [:varchar_type, :text_type])

    create index(:special_cases, [:user_id])
    create unique_index(:special_cases, [:required_field])
  end
end
