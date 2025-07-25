import Config

# Configure the sample app database for test environment
config :sample_app, Sample.Repo,
  database: Path.expand("../priv/test_db.sqlite", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure Ecto repositories
config :sample_app, ecto_repos: [Sample.Repo]

# Configure logger for test
config :logger, level: :warning

# Disable schema cache for tests to ensure fresh introspection
config :drops_relation, :schema_cache, enabled: false
