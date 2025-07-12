defmodule Drops.SQL.Types.Sqlite do
  def to_ecto_type(%{type: :integer, meta: %{default: default}}) when default in [true, false] do
    :boolean
  end

  def to_ecto_type(%{type: :uuid}), do: :binary_id

  def to_ecto_type(%{type: type}), do: type
end
