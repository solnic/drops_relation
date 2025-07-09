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
  alias Ecto.Relation.Schema.Inference
  alias Ecto.Relation.SQL.Introspector

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
  @spec infer_from_table(String.t(), module()) :: Schema.t()
  def infer_from_table(table_name, repo) do
    case Introspector.introspect_table(repo, table_name) do
      {:ok, table} ->
        Inference.to_schema(table)

      {:error, reason} ->
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
end
