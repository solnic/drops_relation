defmodule Drops.Relation.MixProject do
  use Mix.Project

  @source_url "https://github.com/solnic/drops_relation"
  @version "0.0.1"
  @license "LGPL-3.0-or-later"

  def project do
    [
      app: :drops_relation,
      version: @version,
      elixir: "~> 1.14",
      elixirc_options: [warnings_as_errors: false],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: [@license],
      description: ~S"""
      Provides a convenient query API that wraps Ecto.Schema and delegates to Ecto.Repo functions with automatic schema inference from database tables.
      """,
      links: %{"GitHub" => @source_url},
      package: package(),
      docs: docs(),
      source_url: @source_url,
      consolidate_protocols: Mix.env() == :prod,
      elixir_paths: elixir_paths(Mix.env()),
      preferred_cli_env: [
        "test.group": :test
      ],
      aliases: aliases()
    ]
  end

  def elixir_paths(_) do
    ["lib"]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Drops.Relation.Application, []},
      registered: [Drops.Relation.Supervisor]
    ]
  end

  defp package() do
    [
      name: "drops_relation",
      files: ~w(lib/drops/relation .formatter.exs mix.exs README* LICENSE CHANGELOG.md),
      licenses: [@license],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        Core: [
          Drops.Relation,
          Drops.Relation.Query,
          Drops.Relation.Composite
        ],
        Schema: [
          Drops.Relation.Schema,
          Drops.Relation.Schema.MetadataExtractor,
          Drops.Relation.Schema.Field,
          Drops.Relation.Schema.PrimaryKey,
          Drops.Relation.Schema.ForeignKey,
          Drops.Relation.Schema.Index,
          Drops.Relation.Schema.Indices
        ],
        Inference: [
          Drops.Relation.Inference,
          Drops.Relation.SQL.Inference,
          Drops.Relation.SQL.Introspector
        ],
        Cache: [
          Drops.Relation.Cache
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.0"},
      {:telemetry, "~> 1.0"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21.0", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.6", optional: true},
      {:ecto_sqlite3, "~> 0.12", only: [:test, :dev], optional: true},
      {:postgrex, "~> 0.17", only: [:test, :dev], optional: true},
      {:logger_file_backend, "~> 0.0.13", only: [:dev, :test]}
    ]
  end

  # Mix aliases for common tasks
  # Mix aliases for common tasks
  defp aliases do
    [
      "ecto.create": ["drops.relation.dev_setup", "ecto.create"],
      "ecto.drop": ["drops.relation.dev_setup", "ecto.drop --force-drop"],
      "ecto.setup": ["drops.relation.dev_setup", "ecto.create", "ecto.migrate"],
      "ecto.reset": ["drops.relation.dev_setup", "ecto.drop --force-drop", "ecto.setup"],
      "ecto.migrate": ["drops.relation.dev_setup", "ecto.migrate"],
      "ecto.migrations": ["drops.relation.dev_setup", "ecto.migrations"],
      "ecto.dump": ["drops.relation.dev_setup", "ecto.dump"],
      "ecto.load": ["drops.relation.dev_setup", "ecto.load"]
    ]
  end
end
