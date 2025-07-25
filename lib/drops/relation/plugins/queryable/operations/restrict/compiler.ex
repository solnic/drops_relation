defmodule Drops.Relation.Plugins.Queryable.Operations.Restrict.Compiler do
  @moduledoc false

  use Drops.Relation.Plugins.Queryable.Operations.Compiler

  @spec visit(map(), map()) :: {:ok, Ecto.Query.t()} | {:error, [String.t()]}
  def visit(relation, %{query: query, opts: opts}) when is_list(opts) do
    schema = relation.schema

    result =
      Enum.reduce(opts[:restrict], Result.new(query), fn {key, value}, result ->
        case visit_restriction({schema[key], value}, %{query: result.query, key: key}) do
          {:error, error} ->
            %{result | errors: [error | result.errors]}

          updated_query ->
            %{result | query: updated_query}
        end
      end)

    if result.errors == [], do: Result.to_success(result), else: Result.to_error(result)
  end

  defp visit_restriction({nil, _value}, %{key: key}) do
    error(:field_not_found, key)
  end

  defp visit_restriction({field, value}, %{query: query}) when is_list(value) do
    where(query, [r], field(r, ^field.name) in ^value)
  end

  defp visit_restriction({%{meta: %{nullable: true}} = field, nil}, %{query: query}) do
    where(query, [r], is_nil(field(r, ^field.name)))
  end

  defp visit_restriction({%{meta: %{nullable: false}} = field, nil}, _opts) do
    error(:not_nullable, field.name)
  end

  defp visit_restriction({%{type: :boolean} = field, value}, %{query: query})
       when is_boolean(value) do
    where(query, [r], field(r, ^field.name) == ^value)
  end

  defp visit_restriction({field, value}, _opts) when is_boolean(value) do
    error(:not_boolean_field, %{field: field.name, value: value})
  end

  defp visit_restriction({field, value}, %{query: query}) do
    where(query, [r], field(r, ^field.name) == ^value)
  end
end
