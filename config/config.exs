import Config

# Configure ecto repos
config :drops_relation, ecto_repos: [Test.Repos.Sqlite, Test.Repos.Postgres]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config_file = "#{config_env()}.exs"

if File.exists?(Path.join(__DIR__, config_file)) do
  import_config config_file
end

import_config Path.join(__DIR__, "runtime.exs")
