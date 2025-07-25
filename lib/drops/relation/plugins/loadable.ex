defmodule Drops.Relation.Plugins.Loadable do
  @moduledoc false

  alias __MODULE__
  alias Drops.Relation.Loaded

  use Drops.Relation.Plugin

  def on(:before_compile, _, _) do
    quote do
      def load(relation, meta \\ %{}) do
        Drops.Relation.Loadable.load(relation, meta)
      end
    end
  end

  def on(:after_compile, relation, _) do
    quote location: :keep do
      defimpl Drops.Relation.Loadable, for: unquote(relation) do
        def load(relation, meta \\ %{}) do
          Loaded.new(unquote(relation).all(relation), meta)
        end
      end

      defimpl Enumerable, for: unquote(relation) do
        import Ecto.Query

        def count(relation) do
          {:ok, length(Loadable.load(relation).data)}
        end

        def member?(relation, value) do
          {:ok, value in Loadable.load(relation).data}
        end

        def slice(relation) do
          %{data: data} = Loadable.load(relation)
          size = length(data)

          {:ok, size, fn start, count, _step -> Enum.slice(data, start, count) end}
        end

        def reduce(relation, acc, fun) do
          Enumerable.List.reduce(Loadable.load(relation).data, acc, fun)
        end
      end
    end
  end

  @spec load(struct()) :: Drops.Relation.Loaded.t()
  def load(relation, meta \\ %{}) do
    Drops.Relation.Loadable.load(relation, meta)
  end
end
