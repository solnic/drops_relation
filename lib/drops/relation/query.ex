defmodule Drops.Relation.Query do
  alias Drops.Relation.Query.SchemaCompiler

  @doc false
  def generate_functions(schema) do
    SchemaCompiler.visit(schema, %{})
  end
end
