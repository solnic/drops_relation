defmodule Drops.Relation.Plugins.Queryable.Operations.Order.Compiler do
  @moduledoc false

  use Drops.Relation.Plugins.Queryable.Operations.Compiler

  @spec visit(map(), map()) :: {:ok, Ecto.Query.t()} | {:error, [String.t()]}
  def visit(%{schema: schema}, %{query: query, opts: opts}) when is_list(opts) do
    order_list = Keyword.get(opts, :order, [])

    result =
      Enum.reduce(order_list, Result.new(query), fn value, result ->
        case visit_order_spec(value, %{schema: schema, query: result.query}) do
          {:error, error} ->
            %{result | errors: [error | result.errors]}

          updated_query ->
            %{result | query: updated_query}
        end
      end)

    if result.errors == [], do: Result.to_success(result), else: Result.to_error(result)
  end

  defp visit_order_spec(names, %{query: query}) when is_list(names) do
    # Handle list of field names by creating multiple order_by clauses
    Enum.reduce(names, query, fn name, acc_query ->
      order_by(acc_query, [{:asc, ^name}])
    end)
  end

  defp visit_order_spec({direction, name}, %{schema: schema} = opts)
       when direction in [:asc, :desc] do
    case schema[name] do
      nil -> error(:field_not_found, name)
      field -> visit_order_spec({field, direction}, opts)
    end
  end

  defp visit_order_spec(name, %{schema: schema} = opts) when is_atom(name) do
    case schema[name] do
      nil -> error(:field_not_found, name)
      field -> visit_order_spec(field, opts)
    end
  end

  defp visit_order_spec(%{name: name}, %{query: query}) do
    order_by(query, [{:asc, ^name}])
  end

  defp visit_order_spec({%{name: name}, direction}, %{query: query}) do
    order_by(query, [{^direction, ^name}])
  end

  defp visit_order_spec(invalid, _opts) do
    error(:custom, "invalid order specification: #{inspect(invalid)}")
  end
end
