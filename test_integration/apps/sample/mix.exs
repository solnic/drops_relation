defmodule Sample.MixProject do
  use Mix.Project

  def project do
    [
      app: :sample,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      build_path: "../../../_build/__apps__/sample",
      deps_path: "../../../deps/__apps__/sample"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Sample, []}
    ]
  end

  def aliases do
    [
      "ecto.migrate": ["ecto.migrate", "drops.relation.refresh_cache"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.rollback": ["ecto.rollback", "drops.relation.refresh_cache"],
      "ecto.load": ["ecto.load", "drops.relation.refresh_cache"],
      "ecto.reset": ["ecto.drop", "ecto.create", "ecto.migrate"]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17"},
      {:postgrex, "~> 0.17"},
      {:drops_relation, path: "../../.."},
      {:igniter, "~> 0.6"}
    ]
  end
end
