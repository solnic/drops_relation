import Config

# Configure the sample app database
config :sample_app, SampleApp.Repo,
  database: Path.expand("../priv/db.sqlite", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure Ecto repositories
config :sample_app, ecto_repos: [SampleApp.Repo]

# Configure logger
config :logger, level: :debug
