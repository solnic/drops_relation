defmodule Drops.Relation.Plugins.Loadable do
  @moduledoc """
  Plugin that implements the Enumerable protocol for relation modules.

  This plugin allows relation structs to be used with Enum functions by
  implementing the Enumerable protocol. When enumerated, the relation
  is executed and the results are loaded into memory.

  ## Examples

      # Use Enum functions directly on relations
      users = Users.restrict(active: true)

      # Count without executing a separate query
      count = Enum.count(users)

      # Map over results
      names = Enum.map(users, & &1.name)

      # Filter results (after loading)
      admins = Enum.filter(users, & &1.role == "admin")

      # Convert to list
      user_list = Enum.to_list(users)

  ## Performance Note

  This plugin loads all matching records into memory when any Enum function
  is called. For large datasets, consider using the query functions directly
  or implementing pagination.
  """

  use Drops.Relation.Plugin

  def on(:before_compile, _, _) do
    quote do
      def load(relation) do
        all(relation)
      end
    end
  end

  def on(:after_compile, relation, _) do
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
