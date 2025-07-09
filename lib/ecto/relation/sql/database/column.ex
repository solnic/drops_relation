defmodule Ecto.Relation.SQL.Database.Column do
  @moduledoc """
  Represents a database column with complete metadata.

  This struct stores comprehensive information about a database column including
  its name, type, constraints, and other metadata extracted from database introspection.

  ## Examples

      # Simple column
      %Ecto.Relation.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false
      }

      # Primary key column
      %Ecto.Relation.SQL.Database.Column{
        name: "id",
        type: "integer",
        nullable: false,
        default: nil,
        primary_key: true
      }

      # Column with constraints
      %Ecto.Relation.SQL.Database.Column{
        name: "status",
        type: "varchar(20)",
        nullable: false,
        default: "active",
        primary_key: false,
        check_constraints: ["status IN ('active', 'inactive')"]
      }
  """

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          nullable: boolean(),
          default: term(),
          primary_key: boolean(),
          check_constraints: [String.t()]
        }

  defstruct [
    :name,
    :type,
    :nullable,
    :default,
    :primary_key,
    check_constraints: []
  ]

  @doc """
  Creates a new Column struct.

  ## Parameters

  - `name` - The column name as a string
  - `type` - The database type as a string
  - `nullable` - Whether the column allows NULL values
  - `default` - The default value for the column
  - `primary_key` - Whether this column is part of the primary key
  - `check_constraints` - List of check constraint expressions

  ## Examples

      iex> Ecto.Relation.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      %Ecto.Relation.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false,
        check_constraints: []
      }

      iex> constraints = ["status IN ('active', 'inactive')"]
      iex> Ecto.Relation.SQL.Database.Column.new("status", "varchar(20)", false, "active", false, constraints)
      %Ecto.Relation.SQL.Database.Column{
        name: "status",
        type: "varchar(20)",
        nullable: false,
        default: "active",
        primary_key: false,
        check_constraints: ["status IN ('active', 'inactive')"]
      }
  """
  @spec new(String.t(), String.t(), boolean(), term(), boolean(), [String.t()]) :: t()
  def new(name, type, nullable, default, primary_key, check_constraints \\ []) do
    %__MODULE__{
      name: name,
      type: type,
      nullable: nullable,
      default: default,
      primary_key: primary_key,
      check_constraints: check_constraints
    }
  end

  @doc """
  Creates a Column struct from introspection data.

  This is a convenience function for creating columns from the raw data
  returned by database introspection queries.

  ## Parameters

  - `introspection_data` - A map with column metadata from database introspection

  ## Examples

      iex> data = %{
      ...>   name: "email",
      ...>   type: "varchar(255)",
      ...>   not_null: false,
      ...>   default: nil,
      ...>   primary_key: false,
      ...>   check_constraints: []
      ...> }
      iex> Ecto.Relation.SQL.Database.Column.from_introspection(data)
      %Ecto.Relation.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false,
        check_constraints: []
      }
  """
  @spec from_introspection(map()) :: t()
  def from_introspection(data) when is_map(data) do
    %__MODULE__{
      name: Map.get(data, :name) || Map.get(data, "name"),
      type: Map.get(data, :type) || Map.get(data, "type"),
      nullable:
        to_boolean(not (Map.get(data, :not_null, false) || Map.get(data, "not_null", false))),
      default: Map.get(data, :default) || Map.get(data, "default"),
      primary_key:
        to_boolean(Map.get(data, :primary_key, false) || Map.get(data, "primary_key", false)),
      check_constraints:
        Map.get(data, :check_constraints, []) || Map.get(data, "check_constraints", [])
    }
  end

  # Helper function to safely convert values to boolean
  defp to_boolean(value) do
    case value do
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      1 -> true
      0 -> false
      _ -> false
    end
  end

  @doc """
  Checks if the column is part of a primary key.

  ## Examples

      iex> column = Ecto.Relation.SQL.Database.Column.new("id", "integer", false, nil, true)
      iex> Ecto.Relation.SQL.Database.Column.primary_key?(column)
      true

      iex> column = Ecto.Relation.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Ecto.Relation.SQL.Database.Column.primary_key?(column)
      false
  """
  @spec primary_key?(t()) :: boolean()
  def primary_key?(%__MODULE__{primary_key: primary_key}), do: primary_key

  @doc """
  Checks if the column allows NULL values.

  ## Examples

      iex> column = Ecto.Relation.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Ecto.Relation.SQL.Database.Column.nullable?(column)
      true

      iex> column = Ecto.Relation.SQL.Database.Column.new("id", "integer", false, nil, true)
      iex> Ecto.Relation.SQL.Database.Column.nullable?(column)
      false
  """
  @spec nullable?(t()) :: boolean()
  def nullable?(%__MODULE__{nullable: nullable}), do: nullable

  @doc """
  Checks if the column has a default value.

  ## Examples

      iex> column = Ecto.Relation.SQL.Database.Column.new("status", "varchar(20)", false, "active", false)
      iex> Ecto.Relation.SQL.Database.Column.has_default?(column)
      true

      iex> column = Ecto.Relation.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Ecto.Relation.SQL.Database.Column.has_default?(column)
      false
  """
  @spec has_default?(t()) :: boolean()
  def has_default?(%__MODULE__{default: default}), do: not is_nil(default)

  @doc """
  Checks if the column has check constraints.

  ## Examples

      iex> constraints = ["status IN ('active', 'inactive')"]
      iex> column = Ecto.Relation.SQL.Database.Column.new("status", "varchar(20)", false, "active", false, constraints)
      iex> Ecto.Relation.SQL.Database.Column.has_check_constraints?(column)
      true

      iex> column = Ecto.Relation.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Ecto.Relation.SQL.Database.Column.has_check_constraints?(column)
      false
  """
  @spec has_check_constraints?(t()) :: boolean()
  def has_check_constraints?(%__MODULE__{check_constraints: constraints}),
    do: constraints != []
end

defimpl Ecto.Relation.Schema.Inference, for: Ecto.Relation.SQL.Database.Column do
  @moduledoc """
  Implementation of Ecto.Relation.Schema.Inference protocol for Column structs.

  Converts database Column structs to Ecto.Relation.Schema.Field structs
  with proper type mapping and metadata.
  """

  alias Ecto.Relation.Schema.Field

  def to_schema_component(%Ecto.Relation.SQL.Database.Column{} = _column) do
    # For single-argument version, we can't do proper type conversion without table context
    # This should generally not be used - use the two-argument version with table context
    raise ArgumentError,
          "Column conversion requires table context. Use to_schema_component(column, table)."
  end

  def to_schema_component(
        %Ecto.Relation.SQL.Database.Column{} = column,
        %Ecto.Relation.SQL.Database.Table{} = table
      ) do
    alias Ecto.Relation.SQL.Inference

    # Convert database type to Ecto type with full table context
    ecto_type = convert_db_type_to_ecto_type(column, table)
    normalized_type = Inference.normalize_ecto_type(ecto_type)

    # Build metadata including primary key information
    meta = %{
      nullable: column.nullable,
      default: column.default,
      check_constraints: column.check_constraints,
      primary_key: column.primary_key
    }

    Field.new(
      String.to_atom(column.name),
      normalized_type,
      ecto_type,
      String.to_atom(column.name),
      meta
    )
  end

  # Convert database type to Ecto type with full table context
  defp convert_db_type_to_ecto_type(
         %Ecto.Relation.SQL.Database.Column{} = column,
         %Ecto.Relation.SQL.Database.Table{} = table
       ) do
    case table.adapter do
      :postgres ->
        convert_postgres_type_to_ecto_type(column, table)

      :sqlite ->
        convert_sqlite_type_to_ecto_type(column, table)

      _other ->
        # Fallback for unsupported adapters
        :string
    end
  end

  # Convert PostgreSQL types to Ecto types with full table context
  defp convert_postgres_type_to_ecto_type(
         %Ecto.Relation.SQL.Database.Column{} = column,
         %Ecto.Relation.SQL.Database.Table{} = table
       ) do
    # Handle array types first
    if String.ends_with?(column.type, "[]") do
      base_type = String.trim_trailing(column.type, "[]")
      base_column = %{column | type: base_type}
      {:array, convert_postgres_type_to_ecto_type(base_column, table)}
    else
      downcased = String.downcase(column.type)
      convert_postgres_base_type(downcased, column)
    end
  end

  # Convert PostgreSQL base types with column context
  defp convert_postgres_base_type(postgres_type, column) do
    case postgres_type do
      # Integer types - use :id for primary keys, :integer for others
      type when type in ["integer", "int", "int4"] ->
        if column.primary_key, do: :id, else: :integer

      type when type in ["bigint", "int8"] ->
        if column.primary_key, do: :id, else: :integer

      type when type in ["smallint", "int2"] ->
        if column.primary_key, do: :id, else: :integer

      # Serial types are always primary keys
      type
      when type in ["serial", "serial4", "bigserial", "serial8", "smallserial", "serial2"] ->
        :id

      # UUID type - use :binary_id for consistency with Ecto conventions
      "uuid" ->
        :binary_id

      # Floating point types
      type when type in ["real", "float4", "double precision", "float8"] ->
        :float

      # Decimal types
      type when type in ["numeric", "decimal", "money"] ->
        :decimal

      # String types
      type
      when type in ["text", "character varying", "varchar", "char", "character", "name"] ->
        :string

      # Boolean type
      "boolean" ->
        :boolean

      # Binary types
      "bytea" ->
        :binary

      # Date/time types
      "date" ->
        :date

      type
      when type in ["time", "time without time zone", "time with time zone", "timetz"] ->
        :time

      type when type in ["timestamp without time zone", "timestamp"] ->
        :naive_datetime

      type when type in ["timestamp with time zone", "timestamptz"] ->
        :utc_datetime

      # JSON types
      type when type in ["json", "jsonb"] ->
        :map

      # Network and geometric types (mapped to string for now)
      type
      when type in [
             "xml",
             "inet",
             "cidr",
             "macaddr",
             "point",
             "line",
             "lseg",
             "box",
             "path",
             "polygon",
             "circle"
           ] ->
        :string

      # Fallback for unknown types
      _ ->
        :string
    end
  end

  # Convert SQLite types to Ecto types with full table context
  defp convert_sqlite_type_to_ecto_type(
         %Ecto.Relation.SQL.Database.Column{} = column,
         %Ecto.Relation.SQL.Database.Table{} = table
       ) do
    normalized_type = String.upcase(column.type)

    case normalized_type do
      # Integer type - use :id for primary keys and foreign keys, :integer for others
      "INTEGER" ->
        cond do
          column.primary_key -> :id
          is_foreign_key?(column, table) -> :id
          true -> :integer
        end

      # Text type - handle binary_id primary keys and foreign keys specially
      "TEXT" ->
        # In SQLite, binary_id fields are stored as TEXT
        # For single-column primary keys, we can reasonably assume TEXT primary keys are binary_id
        # For composite primary keys, TEXT fields should remain :string
        # For foreign keys, check if they reference a binary_id table
        cond do
          column.primary_key and is_single_column_primary_key?(table) ->
            :binary_id

          is_binary_id_foreign_key?(column, table) ->
            :binary_id

          true ->
            :string
        end

      # Real type
      "REAL" ->
        :float

      # Blob type
      "BLOB" ->
        :binary

      # Numeric types
      type when type in ["NUMERIC", "DECIMAL"] ->
        :decimal

      # UUID type - use Ecto.UUID for SQLite UUID handling
      "UUID" ->
        Ecto.UUID

      # Boolean types (stored as INTEGER in SQLite)
      type when type in ["BOOLEAN", "BOOL"] ->
        :boolean

      # Date/time types
      "DATE" ->
        :date

      type when type in ["DATETIME", "TIMESTAMP"] ->
        :naive_datetime

      "TIME" ->
        :time

      # JSON type
      "JSON" ->
        :map

      # Additional types
      "FLOAT" ->
        :float

      # Fallback for unknown types
      _ ->
        :string
    end
  end

  # Check if a column is a foreign key that references a binary_id table
  defp is_binary_id_foreign_key?(column, table) do
    # Check if this column is part of any foreign key that references a binary_id table
    Enum.any?(table.foreign_keys, fn fk ->
      column.name in fk.columns and references_binary_id_table?(fk)
    end)
  end

  # Check if a table has a single-column primary key
  defp is_single_column_primary_key?(table) do
    length(table.primary_key.columns) == 1
  end

  # Helper function to check if a column is a foreign key
  defp is_foreign_key?(
         %Ecto.Relation.SQL.Database.Column{} = column,
         %Ecto.Relation.SQL.Database.Table{} = table
       ) do
    foreign_key_columns =
      table.foreign_keys
      |> Enum.flat_map(& &1.columns)
      |> MapSet.new()

    column.name in foreign_key_columns
  end

  # Check if a foreign key references a table with binary_id primary key
  defp references_binary_id_table?(foreign_key) do
    # This is a heuristic: if the referenced table name contains "binary_id"
    # we assume it's a binary_id table. This is not ideal but necessary for SQLite
    # where type information is lost during introspection.
    String.contains?(foreign_key.referenced_table, "binary_id")
  end
end
