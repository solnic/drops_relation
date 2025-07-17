defmodule Drops.Relation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Drops.Relation.Supervisor]
    Supervisor.start_link([], opts)
  end
end
