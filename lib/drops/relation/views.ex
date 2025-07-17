defmodule Drops.Relation.Views do
  def generate_functions(relation, view_blocks) do
    views_map = module_map(relation, view_blocks)

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
    Module.concat(relation, Macro.camelize(Atom.to_string(name)))
  end

  defp module_map(relation, view_blocks) do
    Enum.reduce(view_blocks, %{}, fn {name, _block}, acc ->
      Map.put(acc, name, module(relation, name))
    end)
  end
end
