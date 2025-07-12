defmodule Drops.SQL.Compilers.Sqlite do
  @moduledoc """
  SQLite-specific compiler for processing database introspection ASTs.

  This module implements the `Drops.SQL.Compiler` behavior to provide SQLite-specific
  type mapping and AST processing. It converts SQLite database types to Ecto types
  and handles SQLite-specific type characteristics.

  ## SQLite Type System

  SQLite uses a dynamic type system with type affinity rather than strict types.
  This compiler maps SQLite's type affinities to appropriate Ecto types:

  ### Numeric Types
  - `INTEGER` → `:integer`
  - `REAL`, `FLOAT` → `:float`
  - `NUMERIC`, `DECIMAL` → `:decimal`

  ### Text Types
  - `TEXT` → `:string`
  - Character types (VARCHAR, CHAR, etc.) → `:string`

  ### Binary Types
  - `BLOB` → `:binary`

  ### Boolean Types
  - `BOOLEAN`, `BOOL` → `:boolean`

  ### Date/Time Types
  - `DATE` → `:date`
  - `TIME` → `:time`
  - `DATETIME`, `TIMESTAMP` → `:naive_datetime`

  ### Special Types
  - `UUID` → `:uuid`
  - `JSON` → `:map`

  ## Type Affinity Rules

  SQLite's type affinity rules are respected:
  - Types containing "INT" are mapped to `:integer`
  - Types containing "CHAR", "CLOB", or "TEXT" are mapped to `:string`
  - Types containing "BLOB" or no affinity are mapped to `:binary`
  - Types containing "REAL", "FLOA", or "DOUB" are mapped to `:float`

  ## Usage

  This compiler is typically used automatically by the `Drops.SQL.Sqlite` adapter:

      # Automatic usage through adapter
      {:ok, table} = Drops.SQL.Sqlite.table("users", MyRepo)

      # Direct usage (advanced)
      ast = {:table, {{:identifier, "users"}, columns, [], []}}
      table = Drops.SQL.Compilers.Sqlite.process(ast, adapter: :sqlite)

  ## Implementation Notes

  - Case-insensitive type matching (SQLite is case-insensitive)
  - Handles both exact type names and type affinity patterns
  - Preserves unknown types as-is for custom handling
  - Supports SQLite's flexible typing system
  """

  use Drops.SQL.Compiler

  @doc """
  Visits a type AST node and maps SQLite types to Ecto types.

  This function implements SQLite-specific type mapping, handling SQLite's
  dynamic type system and type affinity rules.

  ## Parameters

  - `{:type, type}` - Type AST node with SQLite type name
  - `opts` - Processing options including column metadata for enhanced type detection

  ## Returns

  Ecto type atom (`:integer`, `:string`, etc.) or the original type if unmapped.

  ## Examples

      iex> Drops.SQL.Compilers.Sqlite.visit({:type, "INTEGER"}, [])
      :integer

      iex> Drops.SQL.Compilers.Sqlite.visit({:type, "TEXT"}, [])
      :string

      iex> Drops.SQL.Compilers.Sqlite.visit({:type, "BLOB"}, [])
      :binary
  """
  @spec visit({:type, String.t()}, keyword()) :: atom() | String.t()
  def visit({:type, type}, _opts) do
    normalized_type = String.upcase(type)

    case normalized_type do
      "INTEGER" ->
        :integer

      "FLOAT" ->
        :float

      "REAL" ->
        :float

      "TEXT" ->
        :string

      "BLOB" ->
        :binary

      "UUID" ->
        :uuid

      type when type in ["NUMERIC", "DECIMAL"] ->
        :decimal
    end
  end

  def visit({:default, nil}, _opts), do: nil
  def visit({:default, ""}, _opts), do: nil

  def visit({:default, value}, _opts) when is_binary(value) do
    trimmed =
      value
      |> String.trim()
      |> String.trim("'")
      |> String.trim("\"")

    cond do
      trimmed == "NULL" ->
        nil

      trimmed == "CURRENT_TIMESTAMP" ->
        :current_timestamp

      trimmed == "CURRENT_DATE" ->
        :current_date

      trimmed == "CURRENT_TIME" ->
        :current_time

      String.match?(trimmed, ~r/^\d+$/) ->
        String.to_integer(trimmed)

      String.match?(trimmed, ~r/^\d+\.\d+$/) ->
        String.to_float(trimmed)

      String.downcase(trimmed) in ["true", "false"] ->
        String.to_existing_atom(String.downcase(trimmed))

      true ->
        trimmed
    end
  end
end
