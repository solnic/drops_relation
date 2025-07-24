defmodule Drops.Relation.Operations.Or do
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

defimpl Ecto.Queryable, for: Drops.Relation.Operations.Or do
  def to_query(%Drops.Relation.Operations.Or{
        left: left,
        right: right,
        relation_module: relation_module
      }) do
    left_query = Ecto.Queryable.to_query(left)
    right_query = Ecto.Queryable.to_query(right)

    base_query = Ecto.Queryable.to_query(relation_module.new())

    query_with_left = apply_where_conditions(base_query, left_query)

    apply_or_where_conditions(query_with_left, right_query)
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

  defp apply_or_where_conditions(target_query, source_query) do
    case source_query.wheres do
      [] ->
        target_query

      [single_where] ->
        or_where_expr = %{single_where | op: :or}
        %{target_query | wheres: target_query.wheres ++ [or_where_expr]}

      multiple_wheres ->
        combined_expr = combine_wheres_with_and(multiple_wheres)

        combined_where = %Ecto.Query.BooleanExpr{
          expr: combined_expr,
          op: :or,
          params: Enum.flat_map(multiple_wheres, & &1.params),
          subqueries: Enum.flat_map(multiple_wheres, & &1.subqueries),
          file: __ENV__.file,
          line: __ENV__.line
        }

        %{target_query | wheres: target_query.wheres ++ [combined_where]}
    end
  end

  defp combine_wheres_with_and([first_where | rest_wheres]) do
    Enum.reduce(rest_wheres, first_where.expr, fn where_expr, acc ->
      {:and, [], [acc, where_expr.expr]}
    end)
  end
end

defimpl Enumerable, for: Drops.Relation.Operations.Or do
  def count(or_operation) do
    count =
      Drops.Relation.Plugins.Reading.count(
        relation: or_operation.relation_module,
        queryable: or_operation
      )

    {:ok, count}
  rescue
    _ -> {:error, __MODULE__}
  end

  def member?(or_operation, element) do
    {:ok, element in Enum.to_list(or_operation)}
  end

  def slice(or_operation) do
    list = Enum.to_list(or_operation)
    {:ok, length(list), &Enum.slice(list, &1, &2)}
  end

  def reduce(or_operation, acc, fun) do
    results =
      Drops.Relation.Plugins.Reading.all(
        relation: or_operation.relation_module,
        queryable: or_operation
      )

    Enumerable.List.reduce(results, acc, fun)
  end
end
