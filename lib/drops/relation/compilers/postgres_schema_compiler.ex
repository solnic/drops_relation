defmodule Drops.Relation.Compilers.PostgresSchemaCompiler do
  @moduledoc """
  PostgreSQL-specific schema compiler for converting SQL Database structures to Relation Schema structures.

  This module implements the `Drops.Relation.Compilers.SchemaCompiler` behavior to provide PostgreSQL-specific
  type mapping and field processing. It converts PostgreSQL database types to Ecto types
  and handles PostgreSQL-specific type characteristics.
  """

  use Drops.Relation.Compilers.SchemaCompiler

  def visit({:type, :integer}, %{primary_key: true}), do: :id
  def visit({:type, :integer}, %{foreign_key: true}), do: :id
  def visit({:type, :uuid}, %{primary_key: true}), do: :binary_id
  def visit({:type, :uuid}, %{foreign_key: true}), do: :binary_id
  def visit({:type, :uuid}, _), do: :binary

  def visit({:type, {:array, member}}, _opts) when member in [:json, :jsonb] do
    # TODO: we default to :map because it's not possible to figure it out
    {:array, :map}
  end

  def visit({:type, {:array, member}}, opts), do: {:array, visit({:type, member}, opts)}

  def visit({:type, {:enum, values}}, %{default: default}) when is_list(values) do
    type = {Ecto.Enum, [values: Enum.map(values, &String.to_atom/1)]}

    case default do
      nil ->
        type

      value ->
        {type, %{default: String.to_atom(value)}}
    end
  end

  def visit({:type, type}, %{default: default}) when type in [:json, :jsonb] do
    case default do
      [] -> {:array, :any}
      # TODO: when default is nil, we should rely on configuration rather
      #       than assuming it should be :map
      value when value in [%{}, nil] -> :map
    end
  end
end
