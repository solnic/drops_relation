defmodule Test do
  @protocols [Enumerable, Ecto.Queryable, Drops.Relation.Loadable]

  def loaded_modules do
    :code.all_loaded() |> Enum.map(&elem(&1, 0)) |> MapSet.new()
  end

  def clear_module(module) do
    try do
      :code.purge(module)
      :code.delete(module)
    rescue
      _ -> :ok
    end
  end

  def cleanup_relation_modules(relation_modules) when is_list(relation_modules) do
    Enum.each(relation_modules, &cleanup_relation_modules/1)
  end

  def cleanup_relation_modules(relation_module) do
    if Code.ensure_loaded?(relation_module) do
      if function_exported?(relation_module, :__views__, 0) do
        cleanup_relation_modules(Map.values(relation_module.__views__()))
      end

      Enum.each(
        [
          relation_module,
          Module.concat([relation_module, QueryBuilder]),
          relation_module.__schema_module__()
        ],
        fn module ->
          for protocol <- @protocols do
            impl_module = Module.concat([protocol, module])

            if Code.ensure_loaded?(impl_module) do
              clear_module(impl_module)
            end
          end

          clear_module(module)
        end
      )
    end
  end
end
