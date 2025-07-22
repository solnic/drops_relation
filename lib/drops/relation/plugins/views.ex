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

  def on(:before_compile, relation, _opts) do
    views = context(relation, :views) || []
    views_map = module_map(relation, views)

    getters =
      Enum.map(views_map, fn {name, _} ->
        quote do
          def unquote(name)(),
            do: view(unquote(name))
        end
      end)

    derive_funcs =
      Enum.map(views, fn view ->
        derive_block = extract_derive_block(view.block)

        quote do
          def derive_for(unquote(view.name), view) do
            relation = unquote(derive_block)
            view_relation = view.new(view.__schema_module__(), relation.opts)
            %{view_relation | operations: relation.operations}
          end
        end
      end)

    quote location: :keep do
      @__views__ unquote(Macro.escape(views_map))
      def __views__, do: @__views__

      def view(name), do: Map.get(__views__(), name)

      unquote_splicing(getters)
      unquote_splicing(derive_funcs)
    end
  end

  def on(:after_compile, relation, opts) when not is_map_key(opts, :source) do
    views = context(relation, :views)

    if views do
      Enum.each(views, fn view ->
        create_module(relation, view.name, view.block)
      end)
    end
  end

  def create_module(source, name, block) do
    opts = Keyword.merge(source.opts(), source: source, view: name)
    module_name = module(source, name)

    {:module, module, _, _} =
      Module.create(
        module_name,
        quote location: :keep do
          use unquote(source), unquote(opts)
          unquote(block)

          def queryable(), do: unquote(source).derive_for(unquote(name), __MODULE__)
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

  defp extract_derive_block({:__block__, _meta, expressions}) do
    extract_derive_from_expressions(expressions)
  end

  defp extract_derive_block(expression) do
    extract_derive_from_expressions([expression])
  end

  defp extract_derive_from_expressions(expressions) do
    Enum.find_value(expressions, fn
      {:derive, _meta, [[do: block]]} -> block
      _ -> nil
    end)
  end
end
