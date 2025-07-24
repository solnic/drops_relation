defmodule Drops.Relation.Operations.And do
  @moduledoc false

  defstruct [:left, :right, :relation_module]

  @type t :: %__MODULE__{
          left: any(),
          right: any(),
          relation_module: module()
        }

  @spec new(any(), any(), module()) :: t()
  def new(left, right, relation_module) do
    %__MODULE__{
      left: left,
      right: right,
      relation_module: relation_module
    }
  end
end

defimpl Ecto.Queryable, for: Drops.Relation.Operations.And do
  def to_query(%Drops.Relation.Operations.And{
        left: left,
        right: right,
        relation_module: relation_module
      }) do
    left_query = Ecto.Queryable.to_query(left)
    right_query = Ecto.Queryable.to_query(right)

    base_query = Ecto.Queryable.to_query(relation_module.new())

    query_with_left = apply_where_conditions(base_query, left_query)

    apply_where_conditions(query_with_left, right_query)
  end

  defp apply_where_conditions(target_query, source_query) do
    case source_query.wheres do
      [] ->
        target_query

      wheres ->
        Enum.reduce(wheres, target_query, fn where_expr, acc_query ->
          %{acc_query | wheres: acc_query.wheres ++ [where_expr]}
        end)
    end
  end
end

defimpl Enumerable, for: Drops.Relation.Operations.And do
  def count(and_operation) do
    count =
      Drops.Relation.Plugins.Reading.count(
        relation: and_operation.relation_module,
        queryable: and_operation
      )

    {:ok, count}
  rescue
    _ -> {:error, __MODULE__}
  end

  def member?(and_operation, element) do
    {:ok, element in Enum.to_list(and_operation)}
  end

  def slice(and_operation) do
    list = Enum.to_list(and_operation)
    {:ok, length(list), &Enum.slice(list, &1, &2)}
  end

  def reduce(and_operation, acc, fun) do
    results =
      Drops.Relation.Plugins.Reading.all(
        relation: and_operation.relation_module,
        queryable: and_operation
      )

    Enumerable.List.reduce(results, acc, fun)
  end
end
