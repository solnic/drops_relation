defmodule Drops.SQL.Compilers.Sqlite do
  @moduledoc """
  SQLite-specific compiler for processing database introspection ASTs.

  This module implements the `Drops.SQL.Compiler` behavior to provide SQLite-specific
  type mapping and AST processing. It converts SQLite database types to Ecto types
  and handles SQLite-specific type characteristics.
  """

  use Drops.SQL.Compiler

  @spec visit({:type, String.t()}, map()) :: atom() | String.t()
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

      "JSONB" ->
        :jsonb

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
      trimmed == "{}" ->
        %{}

      trimmed == "[]" ->
        []

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
