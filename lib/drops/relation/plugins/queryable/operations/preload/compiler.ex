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
      when is_atom(spec) do
    name = spec
    nested = nil

    if name in names do
      assoc = associations[name]

      if nested, do: visit_preload({assoc, nested}, opts), else: visit_preload(assoc, opts)
    else
      error(:custom, "association #{inspect(name)} is not defined")
    end
  end

  def visit({name, nested}, %{associations: associations, names: names} = opts)
      when is_atom(name) do
    if name in names do
      assoc = associations[name]

      if nested, do: visit_preload({assoc, nested}, opts), else: visit_preload(assoc, opts)
    else
      error(:custom, "association #{inspect(name)} is not defined")
    end
  end

  def visit(spec, %{associations: _associations, names: _names} = opts)
      when is_list(spec) do
    # Handle list of preload specs
    case spec do
      [] ->
        error(:custom, "empty preload list")

      [first | _] ->
        # For now, just handle the first item in the list
        # This could be expanded to handle multiple preloads
        visit(first, opts)
    end
  end

  defp visit_preload(%{field: name}, %{query: query}) do
    from(q in query, preload: ^name)
  end

  # TODO: add recursive handling of nested so that we can validate their syntax too
  defp visit_preload({%{field: name}, nested}, %{query: query})
       when is_atom(nested) or is_list(nested) do
    from(q in query, preload: ^[{name, nested}])
  end
end
