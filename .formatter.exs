# Used by "mix format"

integration_apps =
  Enum.map(
    Path.wildcard("test_integration/apps/*"),
    &"#{&1}/{config,lib,test,mix}/**/*.{ex,exs}"
  )

inputs =
  [
    "{mix,.formatter}.exs",
    "config/*.exs",
    "lib/**/*.ex",
    "examples/**/*.exs",
    "test/**/*.{ex,exs}",
    "priv/repo/migrations/**/*.exs",
    "priv/repo/*/migrations/**/*.exs"
  ] ++ integration_apps

IO.inspect(inputs)

[inputs: inputs]
