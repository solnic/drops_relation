defmodule Drops.SQL.Compiler do
  alias Drops.SQL.Database.{Table, Column, PrimaryKey, ForeignKey, Index}

  def visit({:table, components}, opts) do
    [name, columns, foreign_keys, indices] = visit(components, opts)

    primary_key =
      PrimaryKey.new(Enum.filter(columns, & &1.meta.primary_key) |> Enum.map(& &1.name))

    Table.new(name, opts[:adapter], primary_key, columns, foreign_keys, indices)
  end

  def visit({:identifier, name}, _opts), do: String.to_atom(name)

  def visit({:column, components}, opts) do
    [name, type, meta] = visit(components, opts)
    Column.new(name, type, meta)
  end

  def visit({:type, type}, _opts), do: type

  def visit({:meta, meta}, opts) when is_map(meta) do
    # Process meta values to convert {:identifier, value} tuples
    Enum.reduce(meta, %{}, fn {key, value}, acc ->
      Map.put(acc, key, visit(value, opts))
    end)
  end

  def visit({:index, components}, opts) do
    [name, columns, meta] = visit(components, opts)
    Index.new(name, columns, meta)
  end

  def visit({:foreign_key, components}, opts) do
    [name, columns, referenced_table, referenced_columns, meta] = visit(components, opts)
    ForeignKey.new(name, columns, referenced_table, referenced_columns, meta)
  end

  def visit(components, opts) when is_list(components) do
    Enum.map(components, &visit(&1, opts))
  end

  def visit(other, _opts), do: other
end
