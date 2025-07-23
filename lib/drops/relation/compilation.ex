defmodule Drops.Relation.Compilation do
  @moduledoc false

  alias Drops.Relation.Config

  defmodule Context do
    @moduledoc false

    defstruct [:relation, :config, macros: %{}]

    def new(relation, config) do
      %Context{relation: relation, config: Config.persist!(config)}
    end

    def update(module, type, args) do
      store(context(module), type, args)
    end

    def store(context, type, args) do
      macros = context.macros
      struct = apply(type, :new, args)
      key = type.key()

      case type.accumulate() do
        true ->
          current_values = Map.get(macros, key, [])
          Map.put(context, :macros, Map.put(macros, key, current_values ++ [struct]))

        false ->
          Map.put(context, :macros, Map.put(macros, key, struct))
      end
    end

    def config(relation, key, default \\ nil) do
      case Config.get(key, default) do
        fun when is_function(fun, 1) ->
          fun.(relation)

        other ->
          other
      end
    end

    def get(module, key), do: Map.get(context(module).macros, key)

    defp context(module), do: Module.get_attribute(module, :context)
  end
end
