defmodule Drops.Relation.Loadable do
  defmacro __using__(_opts) do
    quote do
      @after_compile unquote(__MODULE__)

      def load(relation) do
        all(relation)
      end
    end
  end

  defmacro __after_compile__(env, _) do
    relation = env.module

    quote location: :keep do
      defimpl Enumerable, for: unquote(relation) do
        import Ecto.Query

        def count(relation) do
          {:ok, length(load(relation))}
        end

        def member?(relation, value) do
          case load(relation) do
            {:ok, list} -> {:ok, value in list}
            {:error, _} = error -> error
          end
        end

        def slice(relation) do
          list = load(relation)
          size = length(list)

          {:ok, size, fn start, count, _step -> Enum.slice(list, start, count) end}
        end

        def reduce(relation, acc, fun) do
          Enumerable.List.reduce(load(relation), acc, fun)
        end

        def load(relation) do
          unquote(relation).load(relation)
        end
      end
    end
  end
end
