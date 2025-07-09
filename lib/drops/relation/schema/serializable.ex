defmodule Drops.Relation.Schema.Serializable do
  defmacro __using__(_opts) do
    quote location: :keep do
      defimpl JSON.Encoder, for: __MODULE__ do
        def encode(component, opts) do
          JSON.Encoder.encode(
            %{
              __struct__: component.__struct__.name(),
              attributes:
                Drops.Relation.Schema.Serializable.Dumper.dump(Map.from_struct(component))
            },
            opts
          )
        end
      end

      def name, do: __MODULE__ |> to_string() |> String.split(".") |> List.last()

      def load(json), do: Drops.Relation.Schema.Serializable.Loader.load(json, __MODULE__)
    end
  end

  defprotocol Loader do
    @fallback_to_any true

    @spec load(any()) :: any()
    def load(value)

    @spec load(any(), module()) :: struct()
    def load(value, module)
  end

  defprotocol Dumper do
    @fallback_to_any true

    @spec dump(struct()) :: map()
    def dump(component)

    @spec dump(atom(), any()) :: any()
    def dump(key, value)
  end
end

defimpl Drops.Relation.Schema.Serializable.Dumper, for: Map do
  def dump(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, key, @protocol.dump(value))
    end)
  end

  def dump(_key, map), do: @protocol.dump(map)
end

defimpl Drops.Relation.Schema.Serializable.Dumper, for: Any do
  def dump(_key, value), do: @protocol.dump(value)

  def dump(struct) when is_struct(struct) do
    %{__struct__: struct.__struct__.name(), attributes: Map.from_struct(struct)}
  end

  def dump(value) when is_atom(value) and value !== true and value !== false and value !== nil do
    [:atom, value]
  end

  def dump({type, member}) when is_atom(type) and is_atom(member) do
    [@protocol.dump(type), @protocol.dump(member)]
  end

  def dump(value), do: value
end

defimpl Drops.Relation.Schema.Serializable.Loader, for: Map do
  def load(map) when not is_map_key(map, "__struct__") do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, String.to_atom(key), @protocol.load(value))
    end)
  end

  def load(%{"__struct__" => module, "attributes" => attributes}) when module != "Schema" do
    @protocol.load(attributes, Module.concat(Drops.Relation.Schema, module))
  end

  def load(%{"attributes" => attributes}, module) do
    struct(module, @protocol.load(attributes))
  end

  def load(attributes, module) do
    struct(module, @protocol.load(attributes))
  end
end

defimpl Drops.Relation.Schema.Serializable.Loader, for: List do
  def load(["atom", value]), do: String.to_atom(value)

  def load([["atom", _] = left, ["atom", _] = right]),
    do: {@protocol.load(left), @protocol.load(right)}

  def load(list), do: Enum.map(list, &@protocol.load(&1))
  def load(list, module), do: Enum.map(list, &@protocol.load(&1, module))
end

defimpl Drops.Relation.Schema.Serializable.Loader, for: Any do
  def load(value), do: value
  def load(value, _module), do: value
end
