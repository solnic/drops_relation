defmodule Ecto.Relation.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Validate and persist configuration
    config = Ecto.Relation.Config.validate!()
    Ecto.Relation.Config.persist(config)

    children = [
      # Add any supervised processes here if needed
    ]

    opts = [strategy: :one_for_one, name: Ecto.Relation.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
