import Config

# Configure logger
config :logger, level: :debug

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
config_file = "#{config_env()}.exs"

if File.exists?(Path.join(__DIR__, config_file)) do
  import_config config_file
end

import_config "runtime.exs"
