defmodule Sample do
  @moduledoc """
  Sample application for testing Drops.Relation schema generation.
  """

  use Application

  def start(_type, _args) do
    children = [
      Sample.Repo
    ]

    opts = [strategy: :one_for_one, name: Sample.Supervisor]

    pid = Supervisor.start_link(children, opts)

    Drops.Relation.Cache.warm_up(Sample.Repo, ["users"])

    pid
  end

  def view_module({relation, name}) do
    Module.concat([
      Sample,
      Atom.to_string(relation) |> String.split(".") |> List.last(),
      Views,
      Macro.camelize(Atom.to_string(name))
    ])
  end
end
