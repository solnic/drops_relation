if Mix.env() == :test do
  Code.require_file("test/support/repos.ex")

  defmodule Mix.Tasks.Test.Setup do
    @moduledoc false

    use Mix.Task

    @shortdoc "Sets up the development environment for Drops"

    @impl Mix.Task
    def run(_args) do
      Application.ensure_all_started(:ecto_sql)
      Application.ensure_all_started(:drops_relation)

      case adapter() do
        nil ->
          Test.Repos.start(:all)

        adapter ->
          Test.Repos.start(adapter)
      end
    end

    defp adapter, do: if(name = System.get_env("ADAPTER"), do: String.to_atom(name))
  end
end
