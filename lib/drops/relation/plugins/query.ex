defmodule Drops.Relation.Plugins.Query do
  alias Drops.Relation.Plugins.Query.SchemaCompiler

  use Drops.Relation.Plugin

  def on(:before_compile, _relation, %{schema: schema}) do
    functions = SchemaCompiler.visit(schema, %{})

    quote do
      (unquote_splicing(functions))
    end
  end
end
