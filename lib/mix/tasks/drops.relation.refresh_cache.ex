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

  require Logger

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
      # Ensure application is started
      Mix.Task.run("app.start")

      # Get repositories to process
      repos = get_repos(opts, args)

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
    tables = parse_tables(opts[:tables])
    warm_up = Keyword.get(opts, :warm_up, true)
    verbose = opts[:verbose] || false

    if verbose do
      Logger.info("Refreshing Drops.Relation cache...")
      Logger.info("Repositories: #{inspect(repos)}")
      Logger.info("Tables: #{if tables, do: inspect(tables), else: "all"}")
      Logger.info("Warm up: #{warm_up}")
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

  defp get_repos(opts, args) do
    cond do
      opts[:all_repos] ->
        parse_repo(args)

      opts[:repo] ->
        opts[:repo]
        |> List.wrap()
        |> Enum.map(fn repo_name ->
          ensure_repo(Module.concat([repo_name]), args)
        end)

      true ->
        parse_repo(args)
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
      Logger.info("Processing repository: #{inspect(repo)}")
    end

    Drops.Relation.Cache.clear_repo_cache(repo)

    if verbose do
      Logger.info("  Cache cleared for #{inspect(repo)}")
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
              Logger.info("  No tables found in #{inspect(repo)}")
            end

            {:ok, []}
          else
            Drops.Relation.Cache.warm_up(repo, all_tables)
          end
        end

      case warm_up_result do
        {:ok, warmed_tables} ->
          if verbose do
            Logger.info("  Cache warmed up for #{length(warmed_tables)} tables")
          end

          {:ok, repo, :refreshed, length(warmed_tables)}

        {:error, reason} ->
          Logger.error("  Failed to warm up cache for #{inspect(repo)}: #{inspect(reason)}")

          {:error, repo, reason}
      end
    else
      if verbose do
        Logger.info("  Cache cleared (warm-up skipped)")
      end

      {:ok, repo, :cleared, 0}
    end
  end

  defp get_all_tables(repo) do
    case Drops.SQL.Database.list_tables(repo) do
      {:ok, tables} ->
        tables

      {:error, reason} ->
        Logger.error("  Failed to list tables from #{inspect(repo)}: #{inspect(reason)}")
        []
    end
  end

  defp report_results(results, _verbose) do
    successful = Enum.count(results, &match?({:ok, _, _, _}, &1))
    failed = Enum.count(results, &match?({:error, _, _}, &1))

    total_tables =
      results
      |> Enum.filter(&match?({:ok, _, _, _}, &1))
      |> Enum.map(fn {:ok, _, _, count} -> count end)
      |> Enum.sum()

    if successful > 0 do
      Logger.info("Successfully cached schemas for #{total_tables} tables")
    end

    if failed > 0 do
      Logger.error("Failed to cache schemas for #{failed} tables")

      results
      |> Enum.filter(&match?({:error, _, _}, &1))
      |> Enum.each(fn {:error, repo, reason} ->
        Logger.error("Repository #{inspect(repo)}: #{inspect(reason)}")
      end)
    end

    if failed > 0, do: {:error, :some_failed}, else: :ok
  end
end
