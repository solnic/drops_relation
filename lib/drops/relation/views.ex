defmodule Drops.Relation.Views do
  alias Drops.Relation.Compilation

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
      @views_map unquote(Macro.escape(views_map))
      def view(name), do: Map.get(@views_map, name)

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
