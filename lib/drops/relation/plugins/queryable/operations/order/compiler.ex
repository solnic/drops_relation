defmodule Drops.Relation.Plugins.Queryable.Operations.Order.Compiler do
  @moduledoc false

  use Drops.Relation.Plugins.Queryable.Operations.Compiler

  @spec visit(map(), map()) :: {:ok, Ecto.Query.t()} | {:error, [String.t()]}
  def visit(%{schema: schema}, %{query: query, opts: opts}) when is_list(opts) do
    order_list = Keyword.get(opts, :order, [])

    result =
      Enum.reduce(order_list, Result.new(query), fn value, result ->
        case visit(value, %{schema: schema, query: result.query}) do
          {:error, error} ->
            %{result | errors: [error | result.errors]}

          updated_query ->
            %{result | query: updated_query}
        end
      end)

    if result.errors == [], do: Result.to_success(result), else: Result.to_error(result)
  end

  def visit(names, %{query: query}) when is_list(names) do
    order_by(query, [{:asc, ^names}])
  end

  def visit({direction, name}, %{schema: schema} = opts) when direction in [:asc, :desc] do
    case schema[name] do
      nil -> error(:field_not_found, name)
      field -> visit({field, direction}, opts)
    end
  end

  def visit(name, %{schema: schema} = opts) when is_atom(name) do
    case schema[name] do
      nil -> error(:field_not_found, name)
      field -> visit(field, opts)
    end
  end

  def visit(%{name: name}, %{query: query}) do
    order_by(query, [{:asc, ^name}])
  end

  def visit({%{name: name}, direction}, %{query: query}) do
    order_by(query, [{^direction, ^name}])
  end

  def visit(invalid, _opts) do
    error(:custom, "invalid order specification: #{inspect(invalid)}")
  end
end
