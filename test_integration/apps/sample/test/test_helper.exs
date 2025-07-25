ExUnit.start()

# Start the sample app
{:ok, _} = Application.ensure_all_started(:sample)

# Set up the test database in shared mode for integration tests
repo =
  case System.get_env("ADAPTER") do
    "postgres" -> Sample.Repos.Postgres
    _ -> Sample.Repos.Sqlite
  end

Ecto.Adapters.SQL.Sandbox.mode(repo, :manual)
