import Config

# Configure the sample app database
config :sample_app, SampleApp.Repo,
  database: Path.expand("../priv/db.sqlite", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure Ecto repositories
config :sample_app, ecto_repos: [SampleApp.Repo]

config :sample_app, :drops,
  relation: [
    ecto_schema_namespace: [SampleApp, Schemas],
    view_module: &SampleApp.view_module/1
  ]

# Configure logger
config :logger, level: :debug

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config_file = "#{config_env()}.exs"

if File.exists?(Path.join(__DIR__, config_file)) do
  import_config config_file
end
