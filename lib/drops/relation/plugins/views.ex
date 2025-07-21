defmodule Drops.Relation.Plugins.Views do
  use Drops.Relation.Plugin, imports: [view: 2, derive: 1]

  defmodule Macros.View do
    use Drops.Relation.Plugin.MacroStruct,
      key: :views,
      accumulate: true,
      struct: [:name, :block]

    def new(name, block) when is_atom(name) and is_tuple(block) do
      %Macros.View{name: name, block: block}
    end
  end

  defmodule Macros.Derive do
    use Drops.Relation.Plugin.MacroStruct,
      key: :derive,
      struct: [:block]

    def new(block) when is_tuple(block) do
      %Macros.Derive{block: block}
    end
  end

  defmacro view(name, do: block) do
    quote do
      @context update_context(__MODULE__, Macros.View, [
                 unquote(name),
                 unquote(Macro.escape(block))
               ])
    end
  end

  defmacro derive(do: block) do
    quote do
      @context update_context(__MODULE__, Macros.Derive, [unquote(Macro.escape(block))])
    end
  end

  def on(:before_compile, relation, _) do
    derive = context(relation, :derive)

    derived_new =
      if derive do
        quote do
          def new(), do: unquote(derive.block)
        end
      else
        []
      end

    views = context(relation, :views) || []
    views_map = module_map(relation, views)

    getters =
      Enum.map(views_map, fn {name, _} ->
        quote do
          def unquote(name)(),
            do: view(unquote(name))
        end
      end)

    quote do
      @__views__ unquote(Macro.escape(views_map))
      def __views__, do: @__views__

      def view(name), do: Map.get(__views__(), name)

      unquote_splicing(getters)

      unquote(derived_new)
    end
  end

  def on(:after_compile, relation, _) do
    views = context(relation, :views)

    if views, do: Enum.each(views, &create_module(relation, &1.name, &1.block))
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
    config({relation, name}, :view_module)
  end

  defp module_map(relation, views) do
    Enum.reduce(views, %{}, fn view, acc ->
      Map.put(acc, view.name, module(relation, view.name))
    end)
  end
end
