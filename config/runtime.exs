import Config

env = config_env()

if adapter = System.get_env("ADAPTER") do
  config :drops_relation, ecto_repos: [Module.concat(["Test", "Repos", adapter])]
end

config :logger, :default_handler, config: [file: ~c"log/#{env}.log"]

config :drops_relation, Test.Repos.Sqlite,
  adapter: Ecto.Adapters.SQLite3,
  database: "priv/repo/#{env}.sqlite",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox,
  queue_target: 5000,
  queue_interval: 1000,
  log: :debug,
  priv: "priv/repo/sqlite"

config :drops_relation, Test.Repos.Postgres,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  hostname: "postgres",
  database: "drops_relation_#{env}",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  queue_target: 5000,
  queue_interval: 1000,
  priv: "priv/repo/postgres",
  log: :debug
