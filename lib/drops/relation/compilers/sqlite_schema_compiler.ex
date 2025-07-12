defmodule Drops.Relation.Compilers.SqliteSchemaCompiler do
  @moduledoc """
  SQLite-specific schema compiler for converting SQL Database structures to Relation Schema structures.

  This module implements the `Drops.Relation.Compilers.SchemaCompiler` behavior to provide SQLite-specific
  type mapping and field processing. It converts SQLite database types to Ecto types
  and handles SQLite-specific type characteristics.

  ## SQLite Type System

  SQLite uses a dynamic type system with type affinity rather than strict types.
  This compiler maps SQLite's type affinities to appropriate Ecto types:

  ### Numeric Types
  - `integer` → `:integer`
  - `real`, `float` → `:float`
  - `numeric`, `decimal` → `:decimal`

  ### Text Types
  - `string` → `:string`
  - Character types (VARCHAR, CHAR, etc.) → `:string`

  ### Binary Types
  - `binary` → `:binary`

  ### Boolean Types
  - `boolean`, `bool` → `:boolean`
  - Integer columns with boolean defaults (true/false) → `:boolean`

  ### Date/Time Types
  - `date` → `:date`
  - `time` → `:time`
  - `datetime`, `timestamp` → `:naive_datetime`

  ### Special Types
  - `uuid` → `:binary_id` (SQLite stores UUIDs as binary)
  - `json` → `:map`

  ## Type Affinity Rules

  SQLite's type affinity rules are respected:
  - Types containing "INT" are mapped to `:integer`
  - Types containing "CHAR", "CLOB", or "TEXT" are mapped to `:string`
  - Types containing "BLOB" or no affinity are mapped to `:binary`
  - Types containing "REAL", "FLOA", or "DOUB" are mapped to `:float`

  ## Usage

  This compiler is typically used automatically by database introspection:

      # Automatic usage through database introspection
      {:ok, table} = Drops.SQL.Database.table("users", MyRepo)
      schema = Drops.Relation.Compilers.SqliteSchemaCompiler.process(table, %{})

      # Direct usage (advanced)
      schema = Drops.Relation.Compilers.SqliteSchemaCompiler.visit(table, %{})

  ## Implementation Notes

  - Handles SQLite's dynamic typing system
  - Detects boolean types from integer columns with boolean default values
  - Maps UUID types to `:binary_id` for SQLite compatibility
  - Preserves SQLite-specific type information where possible
  - Uses metadata to determine appropriate Ecto types for special cases
  """

  use Drops.Relation.Compilers.SchemaCompiler

  def visit({:type, :integer}, %{default: default}) when default in [true, false], do: :boolean
  def visit({:type, :uuid}, _opts), do: :binary_id
end
