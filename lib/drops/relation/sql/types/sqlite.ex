defmodule Drops.Relation.SQL.Types.Sqlite do
  alias Drops.Relation.SQL.Database.{Column, Table}

  def to_ecto_type(%Column{} = column, %Table{adapter: :sqlite} = table) do
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
        # In Sqlite, binary_id fields are stored as TEXT
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

      # UUID type - use Ecto.UUID for Sqlite UUID handling
      "UUID" ->
        Ecto.UUID

      # Boolean types (stored as INTEGER in Sqlite)
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
         %Drops.Relation.SQL.Database.Column{} = column,
         %Drops.Relation.SQL.Database.Table{} = table
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
    # we assume it's a binary_id table. This is not ideal but necessary for Sqlite
    # where type information is lost during introspection.
    String.contains?(foreign_key.referenced_table, "binary_id")
  end
end
