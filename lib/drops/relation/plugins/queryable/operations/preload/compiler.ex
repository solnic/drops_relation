defmodule Drops.Relation.Plugins.Queryable.Operations.Preload.Compiler do
  @moduledoc false

  use Drops.Relation.Plugins.Queryable.Operations.Compiler

  @spec visit(map(), map()) :: {:ok, Ecto.Query.t()} | {:error, [String.t()]}
  def visit(%{associations: associations}, %{query: query, opts: opts}) when is_list(opts) do
    result =
      Enum.reduce(opts[:preload], Result.new(query), fn spec, result ->
        case visit(spec, %{
               associations: associations,
               names: Map.keys(associations),
               query: result.query
             }) do
          {:error, error} ->
            %{result | errors: [error | result.errors]}

          updated_query ->
            %{result | query: updated_query}
        end
      end)

    if result.errors == [], do: Result.to_success(result), else: Result.to_error(result)
  end

  def visit(spec, %{associations: associations, names: names} = opts)
      when is_list(spec) or is_atom(spec) do
    {name, nested} =
      case spec do
        name when is_atom(name) ->
          {name, nil}

        {_, _} = result ->
          result
      end

    if name in names do
      assoc = associations[name]

      if nested, do: visit({assoc, nested}, opts), else: visit(assoc, opts)
    else
      error(:custom, "association #{inspect(name)} is not defined")
    end
  end

  def visit(%{field: name}, %{query: query}) do
    from(q in query, preload: ^name)
  end

  # TODO: add recursive handling of nested so that we can validate their syntax too
  def visit({%{field: name}, nested}, %{query: query}) when is_atom(nested) or is_list(nested) do
    from(q in query, preload: ^[{name, nested}])
  end
end
