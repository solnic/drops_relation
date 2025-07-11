defmodule Drops.SQL.Types.Sqlite do
  def to_ecto_type(%{type: :integer, meta: %{default: default}}) do
    if default in [true, false], do: :boolean, else: :integer
  end

  def to_ecto_type(%{type: :uuid}), do: :binary_id

  def to_ecto_type(%{type: type}), do: type
end
