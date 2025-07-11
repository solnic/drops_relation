ExUnit.start()

# Start the sample app
{:ok, _} = Application.ensure_all_started(:sample_app)

# Set up the test database in shared mode for integration tests
Ecto.Adapters.SQL.Sandbox.mode(SampleApp.Repo, :manual)
