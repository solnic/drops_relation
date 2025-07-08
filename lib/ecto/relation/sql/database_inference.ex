defmodule Ecto.Relation.SQL.DatabaseInference do
  @moduledoc """
  Protocol for converting database introspection structs to Ecto.Relation.Schema structs.

  This protocol provides a unified interface for converting database-specific
  introspection results into the standardized schema representation used by
  Ecto.Relation. Each database struct implements this protocol to define
  how it should be converted to schema components.

  ## Protocol Functions

  - `to_schema/1` - Convert a Table struct to a complete Schema struct
  - `to_field/1` - Convert a Column struct to a Field struct
  - `to_primary_key/1` - Convert a PrimaryKey struct to a schema PrimaryKey struct
  - `to_foreign_key/1` - Convert a ForeignKey struct to a schema ForeignKey struct
  - `to_index/1` - Convert an Index struct to a schema Index struct

  ## Examples

      # Convert a complete table to schema
      alias Ecto.Relation.SQL.Database.Table
      table = %Table{name: "users", columns: [...], ...}
      schema = Ecto.Relation.SQL.DatabaseInference.to_schema(table)

      # Convert individual components
      alias Ecto.Relation.SQL.Database.Column
      column = %Column{name: "email", type: "varchar(255)", ...}
      field = Ecto.Relation.SQL.DatabaseInference.to_field(column)
  """

  alias Ecto.Relation.Schema
  alias Ecto.Relation.Schema.{Field, PrimaryKey, ForeignKey, Index, Indices}
  alias Ecto.Relation.SQL.Database

  @doc """
  Converts a database Table struct to a complete Ecto.Relation.Schema struct.

  ## Parameters

  - `table` - A Database.Table struct

  ## Returns

  A complete Schema struct with all metadata converted.

  ## Examples

      iex> table = %Database.Table{name: "users", columns: [...], ...}
      iex> schema = Ecto.Relation.SQL.DatabaseInference.to_schema(table)
      iex> schema.source
      "users"
  """
  @spec to_schema(Database.Table.t()) :: Schema.t()
  def to_schema(%Database.Table{} = table) do
    # Get foreign key column names for metadata
    foreign_key_columns =
      table.foreign_keys
      |> Enum.flat_map(& &1.columns)
      |> MapSet.new()

    # Convert columns to fields with foreign key metadata
    fields =
      Enum.map(table.columns, fn column ->
        field = to_field(column)

        # Add foreign key metadata if this column is part of a foreign key
        if column.name in foreign_key_columns do
          %{field | meta: Map.put(field.meta, :foreign_key, true)}
        else
          field
        end
      end)

    primary_key = to_primary_key(table.primary_key, table.columns)
    foreign_keys = Enum.map(table.foreign_keys, &to_foreign_key/1)
    indices = to_indices(table.indexes)

    Schema.new(
      table.name,
      primary_key,
      foreign_keys,
      fields,
      indices,
      # virtual_fields - cannot be inferred from database structure
      []
    )
  end

  @doc """
  Converts a database Column struct to a Ecto.Relation.Schema.Field struct.

  ## Parameters

  - `column` - A Database.Column struct

  ## Returns

  A Field struct with type information converted from database types to Ecto types.

  ## Examples

      iex> column = %Database.Column{name: "email", type: "varchar(255)", ...}
      iex> field = Ecto.Relation.SQL.DatabaseInference.to_field(column)
      iex> field.name
      :email
  """
  @spec to_field(Database.Column.t()) :: Field.t()
  def to_field(%Database.Column{} = column) do
    # Convert database type to Ecto type
    ecto_type = db_type_to_ecto_type(column.type, column.name)
    normalized_type = normalize_ecto_type(ecto_type)

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

  @doc """
  Converts a database PrimaryKey struct to a schema PrimaryKey struct.

  ## Parameters

  - `primary_key` - A Database.PrimaryKey struct

  ## Returns

  A schema PrimaryKey struct with Field structs for each primary key column.

  ## Examples

      iex> pk = %Database.PrimaryKey{columns: ["id"]}
      iex> schema_pk = Ecto.Relation.SQL.DatabaseInference.to_primary_key(pk)
      iex> length(schema_pk.fields)
      1
  """
  @spec to_primary_key(Database.PrimaryKey.t(), [Database.Column.t()]) :: PrimaryKey.t()
  def to_primary_key(%Database.PrimaryKey{} = primary_key, columns) do
    # Find the actual column metadata for primary key columns
    pk_fields =
      Enum.map(primary_key.columns, fn column_name ->
        # Find the corresponding column
        column = Enum.find(columns, &(&1.name == column_name))

        if column do
          to_field(column)
        else
          # Fallback if column not found
          Field.new(
            String.to_atom(column_name),
            :integer,
            :id,
            String.to_atom(column_name)
          )
        end
      end)

    PrimaryKey.new(pk_fields)
  end

  @doc """
  Converts a database ForeignKey struct to a schema ForeignKey struct.

  ## Parameters

  - `foreign_key` - A Database.ForeignKey struct

  ## Returns

  A schema ForeignKey struct.

  ## Examples

      iex> fk = %Database.ForeignKey{columns: ["user_id"], referenced_table: "users", ...}
      iex> schema_fk = Ecto.Relation.SQL.DatabaseInference.to_foreign_key(fk)
      iex> schema_fk.field
      :user_id
  """
  @spec to_foreign_key(Database.ForeignKey.t()) :: ForeignKey.t()
  def to_foreign_key(%Database.ForeignKey{} = foreign_key) do
    # For now, only handle single-column foreign keys
    # TODO: Add support for composite foreign keys
    field_name =
      case foreign_key.columns do
        [single_column] ->
          String.to_atom(single_column)

        multiple_columns ->
          # For composite keys, use the first column for now
          # This is a limitation that should be addressed
          String.to_atom(hd(multiple_columns))
      end

    referenced_field =
      case foreign_key.referenced_columns do
        [single_column] -> String.to_atom(single_column)
        multiple_columns -> String.to_atom(hd(multiple_columns))
      end

    ForeignKey.new(
      field_name,
      foreign_key.referenced_table,
      referenced_field,
      # association_name - cannot be inferred from database structure
      nil
    )
  end

  @doc """
  Converts a database Index struct to a schema Index struct.

  ## Parameters

  - `index` - A Database.Index struct

  ## Returns

  A schema Index struct.

  ## Examples

      iex> idx = %Database.Index{name: "idx_users_email", columns: ["email"], ...}
      iex> schema_idx = Ecto.Relation.SQL.DatabaseInference.to_index(idx)
      iex> schema_idx.name
      "idx_users_email"
  """
  @spec to_index(Database.Index.t()) :: Index.t()
  def to_index(%Database.Index{} = index) do
    field_names = Enum.map(index.columns, &String.to_atom/1)

    Index.from_names(
      index.name,
      field_names,
      index.unique,
      index.type
    )
  end

  @doc """
  Converts a list of database Index structs to a schema Indices struct.

  ## Parameters

  - `indexes` - A list of Database.Index structs

  ## Returns

  A schema Indices struct containing all converted indexes.

  ## Examples

      iex> indexes = [%Database.Index{...}, %Database.Index{...}]
      iex> indices = Ecto.Relation.SQL.DatabaseInference.to_indices(indexes)
      iex> length(indices.indices)
      2
  """
  @spec to_indices([Database.Index.t()]) :: Indices.t()
  def to_indices(indexes) when is_list(indexes) do
    schema_indices = Enum.map(indexes, &to_index/1)
    Indices.new(schema_indices)
  end

  # Private helper functions

  defp db_type_to_ecto_type(db_type, field_name) do
    # This is a simplified type conversion
    # In a real implementation, you'd use the database-specific type conversion
    # from the Database behavior implementations
    normalized_type = String.upcase(db_type)

    case normalized_type do
      "INTEGER" ->
        if field_name in ["id"] or String.ends_with?(field_name, "_id") do
          :id
        else
          :integer
        end

      "TEXT" ->
        :string

      "VARCHAR" <> _ ->
        :string

      "REAL" ->
        :float

      "FLOAT" <> _ ->
        :float

      "BOOLEAN" ->
        :boolean

      "BOOL" ->
        :boolean

      "UUID" ->
        Ecto.UUID

      "BINARY_ID" ->
        :binary_id

      "DATETIME" ->
        :naive_datetime

      "TIMESTAMP" <> _ ->
        :naive_datetime

      "DATE" ->
        :date

      "TIME" <> _ ->
        :time

      "BLOB" ->
        :binary

      "BYTEA" ->
        :binary

      # Default fallback
      _ ->
        :string
    end
  end

  defp normalize_ecto_type(ecto_type) do
    case ecto_type do
      :id -> :integer
      :binary_id -> :binary
      Ecto.UUID -> :binary
      {:array, inner_type} -> {:array, normalize_ecto_type(inner_type)}
      other -> other
    end
  end
end
