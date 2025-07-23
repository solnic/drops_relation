defmodule Drops.Relation.Repos.Postgres.Migrations.CreateComprehensiveTypesTables do
  use Ecto.Migration

  def change do
    # SQLite-specific types table (for cross-database compatibility testing)
    create table(:type_mapping_tests) do
      # Core SQLite types
      add(:integer_type, :integer)
      add(:real_type, :real)
      add(:text_type, :text)
      add(:blob_type, :binary)
      # SQLite NUMERIC -> Ecto decimal
      add(:numeric_type, :decimal)

      # SQLite interpreted types (stored as other types but interpreted)
      # Stored as INTEGER 0/1
      add(:boolean_type, :boolean)
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

    # PostgreSQL-specific types table
    create table(:postgres_types) do
      # Integer types with aliases
      add(:smallint_type, :smallint)
      # PostgreSQL alias
      add(:int2_type, :smallint)
      add(:integer_type, :integer)
      # PostgreSQL alias
      add(:int_type, :integer)
      # PostgreSQL alias
      add(:int4_type, :integer)
      add(:bigint_type, :bigint)
      # PostgreSQL alias
      add(:int8_type, :bigint)

      # Serial types
      add(:serial_type, :serial)
      add(:bigserial_type, :bigserial)

      # Floating point types
      add(:real_type, :real)
      # PostgreSQL alias
      add(:float4_type, :real)
      add(:double_precision_type, :float)
      # PostgreSQL alias
      add(:float8_type, :float)

      # Decimal types
      add(:numeric_type, :decimal)
      add(:decimal_type, :decimal)
      # PostgreSQL money type
      add(:money_type, :decimal)

      # String types
      add(:character_varying_type, :string)
      add(:varchar_type, :string)
      add(:character_type, :string)
      add(:char_type, :string)
      add(:text_type, :text)
      # PostgreSQL internal name type
      add(:name_type, :string)

      # Date/time types
      add(:date_type, :date)
      add(:time_type, :time)
      add(:time_with_tz_type, :time)
      add(:timestamp_type, :naive_datetime)
      add(:timestamp_with_tz_type, :timestamptz)

      # Binary types
      add(:bytea_type, :binary)

      # Boolean type
      add(:boolean_type, :boolean)

      # JSON types
      add(:json_type, :map)
      add(:jsonb_type, :map)

      # UUID type
      add(:uuid_type, :binary_id)

      # Network types (use string for now since Ecto doesn't have these types)
      # Will map to string for now
      add(:inet_type, :string)
      # Will map to string for now
      add(:cidr_type, :string)
      # Will map to string for now
      add(:macaddr_type, :string)

      # XML type
      add(:xml_type, :text)

      timestamps()
    end

    # PostgreSQL array types table
    create table(:postgres_array_types) do
      add(:integer_array, {:array, :integer})
      add(:text_array, {:array, :string})
      add(:boolean_array, {:array, :boolean})
      add(:uuid_array, {:array, :binary_id})

      timestamps()
    end

    # PostgreSQL geometric types table (these will need custom handling)
    create table(:postgres_geometric_types) do
      # Will need custom type
      add(:point_type, :string)
      # Will need custom type
      add(:line_type, :string)
      # Will need custom type
      add(:lseg_type, :string)
      # Will need custom type
      add(:box_type, :string)
      # Will need custom type
      add(:path_type, :string)
      # Will need custom type
      add(:polygon_type, :string)
      # Will need custom type
      add(:circle_type, :string)

      timestamps()
    end

    # Special cases table for testing edge cases
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

    # PostgreSQL serial type aliases table for testing type alias inference
    create table(:postgres_serial_aliases) do
      # serial4 alias
      add(:serial4_id, :serial)
      # serial8 alias
      add(:serial8_id, :bigserial)
      # serial2 alias
      add(:serial2_id, :smallserial)
      # regular serial for comparison
      add(:regular_serial, :serial)
      # regular bigserial for comparison
      add(:regular_bigserial, :bigserial)
      # regular smallserial for comparison
      add(:regular_smallserial, :smallserial)
    end

    # Create indices for testing index introspection
    create(index(:type_mapping_tests, [:integer_type]))
    create(unique_index(:type_mapping_tests, [:text_type]))
    create(index(:type_mapping_tests, [:boolean_type, :date_type]))

    create(index(:postgres_types, [:integer_type]))
    create(unique_index(:postgres_types, [:uuid_type]))
    create(index(:postgres_types, [:varchar_type, :text_type]))

    create(index(:special_cases, [:user_id]))
    create(unique_index(:special_cases, [:required_field]))
  end
end
