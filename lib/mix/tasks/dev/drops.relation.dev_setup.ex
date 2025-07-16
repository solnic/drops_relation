if Mix.env() == :dev do
  Code.require_file("test/support/repos.ex")

  defmodule Mix.Tasks.Drops.Relation.DevSetup do
    @moduledoc """
    Sets up the development environment for Drops.

    This task ensures that the test support files are loaded and the development
    environment is properly configured for running examples and ecto tasks.

    ## Usage

        mix drops.dev.setup

    This task is automatically called by other development tasks like ecto commands
    and example runners, so you typically don't need to run it manually.

    ## What it does

    - Loads test/support/setup.ex which contains all necessary setup
    - Ensures dependencies are started
    - Sets up the test repository for development use
    - Configures the environment for examples and database operations

    """

    use Mix.Task

    @shortdoc "Sets up the development environment for Drops"

    @impl Mix.Task
    def run(_args) do
      Application.ensure_all_started(:ecto_sql)
      Application.ensure_all_started(:drops_relation)

      :ok = Drops.Relation.Repos.start(adapter(), :auto)
    end

    defp adapter, do: String.to_atom(System.get_env("ADAPTER", "postgres"))
  end
end
