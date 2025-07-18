defmodule Drops.Relation.Query do
  alias Drops.Relation.Query.SchemaCompiler

  alias __MODULE__

  defmacro __using__(_opts) do
    relation = __CALLER__.module
    schema = Module.get_attribute(relation, :schema)

    query_api_ast = Query.generate_functions(schema)

    quote location: :keep do
      (unquote_splicing(query_api_ast))
    end
  end

  @doc false
  def generate_functions(schema) do
    SchemaCompiler.visit(schema, %{})
  end
end
