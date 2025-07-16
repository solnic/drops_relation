defmodule Mix.Tasks.Drops.Example do
  use Mix.Task

  @shortdoc "Runs a Drops example with proper environment setup"

  def run([example | _rest]) do
    example_path = "examples/#{example}.exs"

    unless File.exists?(example_path) do
      Mix.shell().error("Example file not found: #{example_path}")
      Mix.shell().info("To see all available examples, run: mix drops.examples")
      System.halt(1)
    end

    Mix.shell().info("Running example: #{example_path}")
    Mix.shell().info(String.duplicate("=", 60))

    Mix.Task.run("drops.relation.dev_setup")

    elapsed =
      try do
        measure(fn ->
          Code.eval_file(example_path)
        end)
      rescue
        error ->
          Mix.shell().error("Error running example: #{inspect(error)}")
          System.halt(1)
      end

    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("Example completed successfully in #{elapsed}ms!")
  end

  defp measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end
