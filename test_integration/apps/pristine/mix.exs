defmodule Pristine.MixProject do
  use Mix.Project

  def project do
    [
      app: :pristine,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def deps do
    [
      {:drops_relation, path: "../../.."},
      {:igniter, "~> 0.6", optional: true}
    ]
  end
end
