defmodule Drops.SQL.Compilers.Sqlite do
  use Drops.SQL.Compiler

  def visit({:type, type}, _opts) do
    normalized_type = String.upcase(type)

    case normalized_type do
      "INTEGER" ->
        :integer

      "FLOAT" ->
        :float

      "TEXT" ->
        :string

      "REAL" ->
        :float

      "BLOB" ->
        :binary

      "UUID" ->
        :uuid

      type when type in ["NUMERIC", "DECIMAL"] ->
        :decimal

      type when type in ["BOOLEAN", "BOOL"] ->
        :boolean

      type when type in ["DATETIME", "TIMESTAMP"] ->
        :naive_datetime

      "DATE" ->
        :date

      "TIME" ->
        :time

      "JSON" ->
        :map
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
