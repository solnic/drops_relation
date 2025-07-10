defmodule Drops.SQL.Types.Sqlite do
  alias Drops.SQL.Database.{Column, Table}

  def to_ecto_type(%Column{} = column, %Table{adapter: :sqlite}) do
    normalized_type = String.upcase(column.type)

    case normalized_type do
      "INTEGER" ->
        cond do
          column.meta.primary_key -> :id
          is_boolean(column.meta.default) -> :boolean
          true -> :integer
        end

      "TEXT" ->
        :string

      "REAL" ->
        :float

      "BLOB" ->
        :binary

      type when type in ["NUMERIC", "DECIMAL"] ->
        :decimal

      "UUID" ->
        :binary_id

      type when type in ["BOOLEAN", "BOOL"] ->
        :boolean

      "DATE" ->
        :date

      type when type in ["DATETIME", "TIMESTAMP"] ->
        :naive_datetime

      "TIME" ->
        :time

      "JSON" ->
        :map

      "FLOAT" ->
        :float
    end
  end
end
