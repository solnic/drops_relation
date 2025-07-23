defmodule Drops.Relation.Loaded do
  @moduledoc false

  @type t :: %__MODULE__{
          data: [struct()],
          meta: map()
        }

  defstruct [
    :data,
    :meta
  ]

  @spec new([struct()], map()) :: t()
  def new(data, meta \\ %{}) when is_list(data) and is_map(meta) do
    %__MODULE__{
      data: data,
      meta: meta
    }
  end
end

defimpl Enumerable, for: Drops.Relation.Loaded do
  def count(%Drops.Relation.Loaded{data: data}) do
    {:ok, length(data)}
  end

  def member?(%Drops.Relation.Loaded{data: data}, element) do
    {:ok, element in data}
  end

  def slice(%Drops.Relation.Loaded{data: data}) do
    size = length(data)
    {:ok, size, fn start, count, _step -> Enum.slice(data, start, count) end}
  end

  def reduce(%Drops.Relation.Loaded{data: data}, acc, fun) do
    Enumerable.List.reduce(data, acc, fun)
  end
end
