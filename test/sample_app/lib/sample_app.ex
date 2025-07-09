defmodule SampleApp do
  @moduledoc """
  Sample application for testing Drops.Relation schema generation.
  """

  use Application

  def start(_type, _args) do
    children = [
      SampleApp.Repo
    ]

    opts = [strategy: :one_for_one, name: SampleApp.Supervisor]

    pid = Supervisor.start_link(children, opts)

    Ecto.Relation.SchemaCache.warm_up(SampleApp.Repo, ["users"])

    pid
  end
end
