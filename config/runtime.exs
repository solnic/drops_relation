import Config

env = config_env()

# if adapter = System.get_env("ADAPTER") do
#   config :drops_relation, ecto_repos: [Module.concat(["Test", "Repos", adapter])]
# end

config :logger, :default_handler, config: [file: ~c"log/#{env}.log"]

config :drops_relation, Test.Repos.Sqlite,
  adapter: Ecto.Adapters.SQLite3,
  database: "priv/repo/#{env}.sqlite",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/repo/sqlite",
  log: :debug

config :drops_relation, Test.Repos.Postgres,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("POSTGRES_HOST", "postgres"),
  database: "drops_relation_#{env}",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/repo/postgres",
  log: :debug

config :drops_relation, MyApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("POSTGRES_HOST", "postgres"),
  database: "drops_relation_#{env}_my_app",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/repo/postgres",
  log: :debug
