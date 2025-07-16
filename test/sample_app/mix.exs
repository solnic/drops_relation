defmodule SampleApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :sample_app,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Disable type checking to avoid compatibility issues
      elixirc_options: [warnings_as_errors: false, no_warn_undefined: :all]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SampleApp, []}
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17"},
      {:postgrex, "~> 0.17"},
      {:drops_relation, path: "../.."},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.6", optional: true}
    ]
  end
end
