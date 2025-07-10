import Config

env = Mix.env()

if adapter = System.get_env("ADAPTER") do
  config :drops_relation, ecto_repos: [Module.concat(["Ecto", "Relation", "Repos", adapter])]
end

# Ensure log directory exists
log_dir = Path.join(File.cwd!(), "log")

# Configure logger to write Ecto logs to file
config :logger,
  backends: [
    {LoggerFileBackend, :ecto},
    {LoggerFileBackend, :drops_relation}
  ]

# Configure Ecto file logger
config :logger, :ecto,
  path: Path.join(log_dir, "ecto_#{env}.log"),
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:query_time, :decode_time, :queue_time, :connection_time]

# Configure Drops file logger
config :logger, :drops_relation,
  path: Path.join(log_dir, "drops_relation_#{env}.log"),
  level: :debug,
  format: "$time $metadata[$level] $message\n"

# Configure the Sqlite repository for examples in dev environment
config :drops_relation, Drops.Relation.Repos.Sqlite,
  adapter: Ecto.Adapters.SQLite3,
  database: "priv/drops_relation_sqlite_#{env}.db",
  pool_size: 1,
  pool: Ecto.Adapters.SQL.Sandbox,
  queue_target: 5000,
  queue_interval: 1000,
  log: :info,
  priv: "priv/repo/sqlite",
  loggers: [{Ecto.LogEntry, :log, [:ecto]}]

# Configure the PostgreSQL repository for examples in dev environment
config :drops_relation, Drops.Relation.Repos.Postgres,
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
  log: :info,
  loggers: [{Ecto.LogEntry, :log, [:ecto]}]

# Configure schema cache for test environment
config :drops_relation, :schema_cache, enabled: true
