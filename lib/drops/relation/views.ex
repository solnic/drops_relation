defmodule Drops.Relation.Views do
  alias Drops.Relation.Compilation

  alias __MODULE__

  defmacro __using__(_opts) do
    relation = __CALLER__.module
    views = Compilation.Context.get(relation, :views)
    views_ast = Views.generate_functions(relation, views)

    quote location: :keep do
      @after_compile unquote(__MODULE__)
      unquote(views_ast)
    end
  end

  defmacro __after_compile__(env, _) do
    relation = env.module

    views = Compilation.Context.get(relation, :views)

    Enum.each(views, &Views.create_module(relation, &1.name, &1.block))
  end

  def generate_functions(relation, views) do
    views_map = module_map(relation, views)

    getters =
      Enum.map(views_map, fn {name, _} ->
        quote do
          def unquote(name)(),
            do: view(unquote(name)).queryable()
        end
      end)

    quote do
      @__views__ unquote(Macro.escape(views_map))
      def __views__, do: @__views__

      def view(name), do: Map.get(__views__(), name)

      unquote_splicing(getters)
    end
  end

  def create_module(source, name, block) do
    opts = Keyword.merge(source.opts(), source: source, view: true)

    {:module, module, _, _} =
      Module.create(
        module(source, name),
        quote do
          use unquote(source), unquote(opts)
          unquote(block)
        end,
        Macro.Env.location(__ENV__)
      )

    module
  end

  def module(relation, name) do
    Compilation.Context.config({relation, name}, :view_module)
  end

  defp module_map(relation, views) do
    Enum.reduce(views, %{}, fn view, acc ->
      Map.put(acc, view.name, module(relation, view.name))
    end)
  end
end
