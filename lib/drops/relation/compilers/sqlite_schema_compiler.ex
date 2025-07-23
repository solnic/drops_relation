defmodule Drops.Relation.Compilers.SqliteSchemaCompiler do
  @moduledoc false

  use Drops.Relation.Compilers.SchemaCompiler

  def visit({:type, :integer}, %{default: default}) when default in [true, false], do: :boolean
  def visit({:type, :string}, %{default: %{}}), do: :map
  def visit({:type, :string}, %{default: []}), do: {:array, :any}
  def visit({:type, :uuid}, _opts), do: :binary_id

  def visit({:type, :jsonb}, %{default: default}) do
    case default do
      [] -> {:array, :any}
      # TODO: when default is nil, we should rely on configuration rather
      #       than assuming it should be :map
      value when value in [%{}, nil] -> :map
    end
  end
end
