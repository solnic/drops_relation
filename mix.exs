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
      deps: deps(Mix.env(), System.version()),
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
      test_coverage: [tool: ExCoveralls],
      aliases: aliases()
    ]
  end

  def elixir_paths(_) do
    ["lib"]
  end

  def cli do
    [
      preferred_envs: [
        "ecto.migrate": :test,
        "ecto.reset": :test,
        "ecto.drop": :test,
        "ecto.create": :test,
        "ecto.setup": :test,
        test: :test,
        "test.refresh_cache": :test,
        "test.setup": :test,
        "test.example": :test,
        "test.cov.update_tasks": :test,
        "test.group": :test,
        "test.integration": :test,
        "test.coverage": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

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
      files: ~w(lib .formatter.exs mix.exs README* LICENSE CHANGELOG.md),
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
      authors: ["Peter Solnica"],
      logo: "assets/logo.png",
      favicon: "assets/favicon.png",
      filter_modules: "Drops.*",
      extras: [
        "README.md"
      ],
      # nest_modules_by_prefix: [
      #   Drops.Relation.Plugins,
      #   Drops.Relation.Schema,
      #   Drops.SQL.Database,
      #   Drops.SQL.Compilers
      # ],
      groups_for_modules: [
        "Core API": [
          Drops.Relation,
          Drops.Relation.Config,
          Drops.Relation.Plugins.Schema,
          Drops.Relation.Plugins.Views
        ],
        "Query API": [
          Drops.Relation.Plugins.Reading,
          Drops.Relation.Plugins.Writing,
          Drops.Relation.Plugins.AutoRestrict,
          Drops.Relation.Plugins.Pagination
        ],
        "Advanced Composition": [
          Drops.Relation.Query,
          Drops.Relation.Plugins.Ecto.Query
        ],
        "Relation Schema": [
          Drops.Relation.Schema,
          Drops.Relation.Schema.Field,
          Drops.Relation.Schema.PrimaryKey,
          Drops.Relation.Schema.ForeignKey,
          Drops.Relation.Schema.Index
        ],
        "Database Introspection": [
          Drops.SQL.Database,
          Drops.SQL.Database.Table,
          Drops.SQL.Database.Column,
          Drops.SQL.Database.PrimaryKey,
          Drops.SQL.Database.ForeignKey,
          Drops.SQL.Database.Index,
          Drops.SQL.Postgres,
          Drops.SQL.Sqlite,
          Drops.SQL.Compiler,
          Drops.SQL.Compilers.Postgres,
          Drops.SQL.Compilers.Sqlite
        ],
        "Schema Cache": [
          Drops.Relation.Cache
        ]
      ]
    ]
  end

  defp deps(_, version) when version != "all" do
    base_deps = deps(:test, "all")

    if Version.match?(version, "< 1.18.0") do
      base_deps ++
        [
          {:jason, "~> 1.4"}
        ]
    else
      base_deps
    end
  end

  defp deps(_, _) do
    [
      {:nimble_options, "~> 1.0"},
      {:drops_inflector, "~> 0.2"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:igniter, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ecto_sqlite3, "~> 0.12", only: [:test, :dev], optional: true, runtime: false},
      {:postgrex, "~> 0.17", only: [:test, :dev], optional: true, runtime: false}
    ]
  end

  defp aliases do
    [
      "test.refresh_cache": ["test.setup", "drops.relation.refresh_cache"],
      "ecto.migrate": ["test.setup", "ecto.migrate", "test.refresh_cache"],
      "ecto.rollback": ["ecto.rollback", "test.refresh_cache"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop --force-drop", "ecto.create", "ecto.migrate"],
      "ecto.dump": ["test.setup", "ecto.dump"],
      "ecto.load": ["test.setup", "ecto.load", "test.refresh_cache"],
      "test.integration": ["cmd cd test/sample && mix test"],
      "test.cov": ["coveralls.json", "test.cov.update_tasks"]
    ]
  end
end
