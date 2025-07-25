import Config

env = config_env()
adapter = System.get_env("ADAPTER", "sqlite")
repo_name = if adapter == "sqlite", do: "Sqlite", else: "Postgres"

repo = Module.concat(["Sample", "Repos", repo_name])

config :sample, ecto_repos: [repo]

config :logger, :default_handler, config: [file: ~c"log/#{env}.log"]

config :sample, :drops,
  relation: [
    repo: repo
  ]

case adapter do
  "sqlite" ->
    config :sample, Sample.Repos.Sqlite,
      adapter: Ecto.Adapters.SQLite3,
      database: "priv/repo/#{env}.sqlite",
      log: :debug

  "postgres" ->
    config :sample, Sample.Repos.Postgres,
      adapter: Ecto.Adapters.Postgres,
      username: "postgres",
      password: "postgres",
      hostname: "postgres",
      database: "sample_app_#{env}",
      log: :debug
end
