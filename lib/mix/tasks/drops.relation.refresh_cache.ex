defmodule Mix.Tasks.Drops.Relation.RefreshCache do
  @moduledoc """
  Refreshes the Drops.Relation cache for all tables in specified repositories.

  This task clears the existing cache and optionally warms it up again by
  inferring schemas for all tables in the database. This is useful when
  database schema changes have been made and you want to ensure the cache
  is up to date.

  ## Usage

      mix drops.relation.refresh_cache [options]

  ## Options

    * `--repo` - The repository to refresh cache for (can be specified multiple times)
    * `--all-repos` - Refresh cache for all configured repositories
    * `--tables` - Comma-separated list of specific tables to refresh (optional)
    * `--warm-up` - Whether to warm up the cache after clearing (default: true)
    * `--verbose` - Show detailed output during cache refresh

  ## Examples

      # Refresh cache for all configured repositories
      mix drops.relation.refresh_cache --all-repos

      # Refresh cache for a specific repository
      mix drops.relation.refresh_cache --repo MyApp.Repo

      # Refresh cache for specific tables only
      mix drops.relation.refresh_cache --repo MyApp.Repo --tables users,posts,comments

      # Clear cache without warming up
      mix drops.relation.refresh_cache --repo MyApp.Repo --warm-up false

      # Verbose output
      mix drops.relation.refresh_cache --repo MyApp.Repo --verbose

  ## Notes

  - This task requires the application to be started to access repository configuration
  - If no repositories are specified, it will use all repositories configured in `:ecto_repos`
  - The cache must be enabled for this task to have any effect
  - Tables that don't exist in the database will be skipped with a warning
  """

  use Mix.Task
  import Mix.Ecto

  @shortdoc "Refreshes the Drops.Relation cache for all tables"

  @switches [
    repo: [:string, :keep],
    all_repos: :boolean,
    tables: :string,
    warm_up: :boolean,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    r: :repo,
    a: :all_repos,
    t: :tables,
    w: :warm_up,
    v: :verbose,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      :ok
    else
      # Ensure the application is started
      Mix.Task.run("app.start")

      # Get repositories to process
      repos = get_repos(opts)

      if Enum.empty?(repos) do
        Mix.shell().error(
          "No repositories found. Use --repo or --all-repos to specify repositories."
        )

        {:error, :no_repos}
      else
        process_cache_refresh(repos, opts)
      end
    end
  end

  defp process_cache_refresh(repos, opts) do
    # Parse options
    tables = parse_tables(opts[:tables])
    warm_up = Keyword.get(opts, :warm_up, true)
    verbose = opts[:verbose] || false

    if verbose do
      Mix.shell().info("Refreshing Drops.Relation cache...")
      Mix.shell().info("Repositories: #{inspect(repos)}")
      Mix.shell().info("Tables: #{if tables, do: inspect(tables), else: "all"}")
      Mix.shell().info("Warm up: #{warm_up}")
    end

    # Process each repository
    results =
      Enum.map(repos, fn repo ->
        refresh_repo_cache(repo, tables, warm_up, verbose)
      end)

    # Report results
    report_results(results, verbose)
  end

  # Private functions

  defp get_repos(opts) do
    cond do
      opts[:all_repos] ->
        parse_repo([])

      opts[:repo] ->
        mod = opts[:repo] |> String.split(".") |> Module.concat()
        if ensure_repo(mod), do: [mod]

      true ->
        parse_repo([])
    end
  end

  defp parse_tables(nil), do: nil

  defp parse_tables(tables_string) do
    tables_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp refresh_repo_cache(repo, tables, warm_up, verbose) do
    if verbose do
      Mix.shell().info("Processing repository: #{inspect(repo)}")
    end

    Drops.Relation.Cache.clear_repo_cache(repo)

    if verbose do
      Mix.shell().info("  Cache cleared for #{inspect(repo)}")
    end

    # Warm up if requested
    if warm_up do
      warm_up_result =
        if tables do
          # Warm up specific tables
          Drops.Relation.Cache.warm_up(repo, tables)
        else
          # Get all tables from the database and warm up
          all_tables = get_all_tables(repo)

          if Enum.empty?(all_tables) do
            if verbose do
              Mix.shell().info("  No tables found in #{inspect(repo)}")
            end

            {:ok, []}
          else
            Drops.Relation.Cache.warm_up(repo, all_tables)
          end
        end

      case warm_up_result do
        {:ok, warmed_tables} ->
          if verbose do
            Mix.shell().info("  Cache warmed up for #{length(warmed_tables)} tables")
          end

          {:ok, repo, :refreshed, length(warmed_tables)}

        {:error, reason} ->
          Mix.shell().error("  Failed to warm up cache for #{inspect(repo)}: #{inspect(reason)}")

          {:error, repo, reason}
      end
    else
      if verbose do
        Mix.shell().info("  Cache cleared (warm-up skipped)")
      end

      {:ok, repo, :cleared, 0}
    end
  end

  defp get_all_tables(repo) do
    case repo.__adapter__() do
      Ecto.Adapters.Postgres ->
        query = """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_type = 'BASE TABLE'
        """

        result = Ecto.Adapters.SQL.query!(repo, query, [])
        Enum.map(result.rows, fn [table_name] -> table_name end)

      Ecto.Adapters.MyXQL ->
        query = """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
        AND table_type = 'BASE TABLE'
        """

        result = Ecto.Adapters.SQL.query!(repo, query, [])
        Enum.map(result.rows, fn [table_name] -> table_name end)

      Ecto.Adapters.SQLite3 ->
        query = """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%'
        """

        result = Ecto.Adapters.SQL.query!(repo, query, [])
        Enum.map(result.rows, fn [table_name] -> table_name end)

      _ ->
        Mix.shell().error("  Unsupported database adapter for #{inspect(repo)}")
        []
    end
  end

  defp report_results(results, verbose) do
    successful = Enum.count(results, &match?({:ok, _, _, _}, &1))
    failed = Enum.count(results, &match?({:error, _, _}, &1))

    total_tables =
      results
      |> Enum.filter(&match?({:ok, _, _, _}, &1))
      |> Enum.map(fn {:ok, _, _, count} -> count end)
      |> Enum.sum()

    Mix.shell().info("")
    Mix.shell().info("Cache refresh completed:")
    Mix.shell().info("  Repositories processed: #{successful + failed}")
    Mix.shell().info("  Successful: #{successful}")
    Mix.shell().info("  Failed: #{failed}")
    Mix.shell().info("  Total tables cached: #{total_tables}")

    if failed > 0 do
      Mix.shell().info("")
      Mix.shell().info("Failed repositories:")

      results
      |> Enum.filter(&match?({:error, _, _}, &1))
      |> Enum.each(fn {:error, repo, reason} ->
        Mix.shell().info("  #{inspect(repo)}: #{inspect(reason)}")
      end)
    end

    if verbose do
      Mix.shell().info("")
      Mix.shell().info("Detailed results:")

      Enum.each(results, fn
        {:ok, repo, action, count} ->
          Mix.shell().info("  #{inspect(repo)}: #{action} (#{count} tables)")

        {:error, repo, reason} ->
          Mix.shell().info("  #{inspect(repo)}: error - #{inspect(reason)}")
      end)
    end

    if failed > 0, do: {:error, :some_failed}, else: :ok
  end

  defp ensure_repo(repo) do
    if Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0) do
      true
    else
      Mix.shell().error("Repository #{inspect(repo)} is not available or not an Ecto repository")
      false
    end
  end
end
