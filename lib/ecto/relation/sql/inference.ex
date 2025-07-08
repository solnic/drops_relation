defmodule Ecto.Relation.SQL.Inference do
  @moduledoc """
  Unified schema inference implementation for database table introspection.

  This module consolidates all schema inference logic into a single, reusable
  implementation that can be used by both runtime schema inference (for dynamic
  relation modules) and code generation (for explicit relation files).

  The module provides a single source of truth for:
  - Database table introspection
  - Type conversion from database types to Ecto types
  - Field metadata extraction
  - Primary key detection
  - Index extraction
  - Schema struct creation

  ## Usage

      # Create schema from database table
      schema = Ecto.Relation.SQL.Inference.infer_from_table("users", MyApp.Repo)

      # Create schema with custom options
      schema = Ecto.Relation.SQL.Inference.infer_from_table("users", MyApp.Repo,
        include_indices: true,
        include_timestamps: false
      )
  """

  alias Ecto.Relation.Schema
  alias Ecto.Relation.Schema.{Field, PrimaryKey, Indices}
  alias Ecto.Relation.SQL.{Introspector, DatabaseToSchema}

  require Logger

  @doc """
  Infers a complete Ecto.Relation.Schema from a database table.

  This is the main entry point for schema inference. It performs database
  introspection and creates a complete Schema struct with all metadata.

  ## Parameters

  - `table_name` - The database table name to introspect
  - `repo` - The Ecto repository module for database access
  - `opts` - Optional configuration (see options below)

  ## Options

  - `:include_indices` - Whether to extract index information (default: true)
  - `:include_timestamps` - Whether to include timestamp fields (default: true)
  - `:default_primary_key` - Default primary key when none found (default: [:id])

  ## Returns

  A `Ecto.Relation.Schema.t()` struct containing all inferred metadata.

  ## Examples

      iex> schema = Ecto.Relation.SQL.Inference.infer_from_table("users", MyApp.Repo)
      iex> schema.source
      "users"
      iex> length(schema.fields)
      5
  """
  @spec infer_from_table(String.t(), module(), keyword()) :: Schema.t()
  def infer_from_table(table_name, repo, opts \\ []) do
    include_indices = Keyword.get(opts, :include_indices, true)
    _include_timestamps = Keyword.get(opts, :include_timestamps, true)

    # Use the new database introspection to get complete table metadata
    case Introspector.introspect_table(repo, table_name) do
      {:ok, table} ->
        # Convert the database table struct to a schema using the protocol
        schema = table_to_schema(table)

        # Apply filtering options and handle default primary key
        filtered_schema = apply_filtering_options(schema, opts)
        schema_with_pk = apply_default_primary_key(filtered_schema, opts)

        # Ensure indices are included/excluded based on options
        final_schema =
          if include_indices do
            schema_with_pk
          else
            %{schema_with_pk | indices: Indices.new([])}
          end

        final_schema

      {:error, reason} ->
        # No fallbacks - if we can't introspect, we fail
        raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
    end
  end

  @doc """
  Normalizes Ecto types to their base types.

  ## Parameters

  - `ecto_type` - The Ecto type to normalize

  ## Returns

  The normalized Ecto type.

  ## Examples

      iex> Ecto.Relation.SQL.Inference.normalize_ecto_type(:id)
      :integer
      iex> Ecto.Relation.SQL.Inference.normalize_ecto_type(:string)
      :string
  """
  @spec normalize_ecto_type(atom() | tuple()) :: atom() | tuple()
  def normalize_ecto_type(ecto_type) do
    case ecto_type do
      :id -> :integer
      :binary_id -> :binary
      Ecto.UUID -> :binary
      {:array, inner_type} -> {:array, normalize_ecto_type(inner_type)}
      other -> other
    end
  end

  # Private helper functions

  # Apply filtering options to the schema
  defp apply_filtering_options(schema, opts) do
    include_timestamps = Keyword.get(opts, :include_timestamps, true)

    if include_timestamps do
      schema
    else
      # Filter out timestamp fields
      filtered_fields =
        Enum.reject(schema.fields, fn field ->
          field.name in [:inserted_at, :updated_at, :created_at, :modified_at]
        end)

      %{schema | fields: filtered_fields}
    end
  end

  # Apply default primary key if no primary key is found
  defp apply_default_primary_key(schema, opts) do
    default_primary_key = Keyword.get(opts, :default_primary_key, [:id])

    # Check if schema has any primary key fields
    if length(schema.primary_key.fields) == 0 do
      # Create default primary key fields
      default_pk_fields =
        Enum.map(default_primary_key, fn field_name ->
          # Try to find the field in the schema fields
          existing_field = Enum.find(schema.fields, &(&1.name == field_name))

          if existing_field do
            existing_field
          else
            # Create a default field
            Field.new(field_name, :integer, :id, field_name)
          end
        end)

      new_primary_key = PrimaryKey.new(default_pk_fields)
      %{schema | primary_key: new_primary_key}
    else
      schema
    end
  end

  # Converts a database Table struct to a schema using the protocol for components
  defp table_to_schema(%Ecto.Relation.SQL.Database.Table{} = table) do
    alias Ecto.Relation.Schema.Indices

    # Get foreign key column names for metadata
    foreign_key_columns =
      table.foreign_keys
      |> Enum.flat_map(& &1.columns)
      |> MapSet.new()

    # Convert columns to fields using the protocol with table context
    fields =
      Enum.map(table.columns, fn column ->
        field = DatabaseToSchema.to_schema_component(column, table)

        # Add foreign key metadata if this column is part of a foreign key
        if column.name in foreign_key_columns do
          %{field | meta: Map.put(field.meta, :foreign_key, true)}
        else
          field
        end
      end)

    # Convert primary key by finding the corresponding fields
    pk_fields =
      Enum.map(table.primary_key.columns, fn column_name ->
        # Find the field that was already converted
        Enum.find(fields, &(&1.name == String.to_atom(column_name)))
      end)
      |> Enum.reject(&is_nil/1)

    primary_key = PrimaryKey.new(pk_fields)

    # Convert foreign keys using protocol
    foreign_keys = Enum.map(table.foreign_keys, &DatabaseToSchema.to_schema_component/1)

    # Convert indices using protocol
    schema_indices = Enum.map(table.indexes, &DatabaseToSchema.to_schema_component/1)
    indices = Indices.new(schema_indices)

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
end
