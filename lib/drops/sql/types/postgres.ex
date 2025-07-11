defmodule Drops.SQL.Types.Postgres do
  def to_ecto_type(%{type: :integer, meta: %{primary_key: true}}), do: :id
  def to_ecto_type(%{type: :integer, meta: %{foreign_key: true}}), do: :id
  def to_ecto_type(%{type: :uuid, meta: %{primary_key: true}}), do: :binary_id
  def to_ecto_type(%{type: :uuid, meta: %{foreign_key: true}}), do: :binary_id
  def to_ecto_type(%{type: :uuid}), do: :binary

  def to_ecto_type(%{type: {:array, member}}), do: {:array, to_ecto_type(member)}

  # Catch-all
  def to_ecto_type(%{type: type}), do: type
end
