defmodule Drops.Relation.Compilers.PostgresSchemaCompiler do
  @moduledoc """
  PostgreSQL-specific schema compiler for converting SQL Database structures to Relation Schema structures.

  This module implements the `Drops.Relation.Compilers.SchemaCompiler` behavior to provide PostgreSQL-specific
  type mapping and field processing. It converts PostgreSQL database types to Ecto types
  and handles PostgreSQL-specific type characteristics.

  ## PostgreSQL Type System

  PostgreSQL has a sophisticated type system that this compiler maps to Ecto types:

  ### Integer Types
  - `integer`, `int`, `int4`, `bigint`, `int8`, `smallint`, `int2` → `:integer`
  - Serial types (`serial`, `bigserial`, `smallserial`) → `:integer`
  - Primary key integers → `:id`
  - Foreign key integers → `:id`

  ### UUID Types
  - `uuid` → `:binary` (general use)
  - Primary key UUIDs → `:binary_id`
  - Foreign key UUIDs → `:binary_id`

  ### Array Types
  - `integer[]`, `text[]`, etc. → `{:array, base_type}`
  - Recursive processing for nested arrays

  ### Other Types
  - Text types (`text`, `varchar`, etc.) → `:string`
  - Floating point types → `:float`
  - Decimal types → `:decimal`
  - Boolean type → `:boolean`
  - Date/time types → `:date`, `:time`, `:naive_datetime`, `:utc_datetime`
  - JSON types → `:map`

  ## Usage

  This compiler is typically used automatically by database introspection:

      # Automatic usage through database introspection
      {:ok, table} = Drops.SQL.Database.table("users", MyRepo)
      schema = Drops.Relation.Compilers.PostgresSchemaCompiler.process(table, %{})

      # Direct usage (advanced)
      schema = Drops.Relation.Compilers.PostgresSchemaCompiler.visit(table, %{})

  ## Implementation Notes

  - Handles PostgreSQL's internal type names (e.g., `int4` → `integer`)
  - Supports array type detection and recursive processing
  - Maps primary key and foreign key fields to appropriate ID types
  - Preserves PostgreSQL-specific type information where possible
  - Uses metadata to determine appropriate Ecto types for special cases
  """

  use Drops.Relation.Compilers.SchemaCompiler

  def visit({:type, :integer}, %{primary_key: true}), do: :id
  def visit({:type, :integer}, %{foreign_key: true}), do: :id
  def visit({:type, :uuid}, %{primary_key: true}), do: :binary_id
  def visit({:type, :uuid}, %{foreign_key: true}), do: :binary_id
  def visit({:type, :uuid}, _), do: :binary
  def visit({:type, {:array, member}}, opts), do: {:array, visit({:type, member}, opts)}
end
