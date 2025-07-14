defmodule Drops.Relation.Cache do
  @moduledoc """
  Persistent cache for inferred Drops.Relation schemas based on migration file digests.

  This module provides efficient caching of schema inference results to avoid
  redundant database introspection during compilation. The cache persists across
  application restarts using JSON files and is invalidated automatically when
  migration files change, ensuring schemas stay in sync with the database structure.

  ## Features

  - JSON file-based persistent caching that survives application restarts
  - Migration digest-based cache invalidation
  - Multi-repository support
  - Graceful fallback when file operations fail

  ## Usage

      # Cache a schema explicitly
      Drops.Relation.Cache.cache_schema(MyApp.Repo, "users", schema)

      # Get cached schema (returns nil if not cached)
      schema = Drops.Relation.Cache.get_cached_schema(MyApp.Repo, "users")

      # Clear cache for a specific repository
      Drops.Relation.Cache.clear_repo_cache(MyApp.Repo)

      # Get cached schema or empty schema if not cached
      schema = Drops.Relation.Cache.maybe_get_cached_schema(MyApp.Repo, "users")

      # Check if cache is enabled
      if Drops.Relation.Cache.enabled?() do
        # Cache-specific logic
      end

      # Warm up cache for specific tables
      Drops.Relation.Cache.warm_up(MyApp.Repo, ["users", "posts", "comments"])
  """

  alias Drops.Relation.Schema

  require Logger

  alias Drops.Relation.Schema

  @digest_file_name "migrations_digest.txt"

  ## Public API

  @doc """
  Gets a cached schema if available.

  Returns the cached schema for the given repository and table name if it exists
  and the migration digest matches. Returns nil if not cached or digest mismatch.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The database table name

  ## Returns

  The cached schema or nil if not cached.

  ## Examples

      schema = get_cached_schema(MyApp.Repo, "users")
      if schema do
        # Use cached schema
      else
        # Need to infer schema
      end
  """
  @spec maybe_get_cached_schema(module(), String.t()) :: any()
  def maybe_get_cached_schema(repo, table_name) do
    case get_cached_schema(repo, table_name) do
      nil ->
        Schema.empty(table_name)

      schema ->
        schema
    end
  end

  @spec get_cached_schema(module(), String.t()) :: any() | nil
  def get_cached_schema(repo, table_name) do
    current_digest = get_migrations_digest(repo)
    cache_file = get_cache_file_path(repo, table_name)

    case read_cache_file(cache_file) do
      {:ok, %{"schema" => schema, "digest" => stored_digest}} ->
        if current_digest == stored_digest do
          log_cache_event("Schema cache hit for #{repo}.#{table_name}", :debug)

          Schema.load(schema)
        else
          File.rm(cache_file)

          log_cache_event(
            "Schema cache miss for #{repo}.#{table_name} (digest mismatch: current=#{current_digest}, stored=#{stored_digest})",
            :debug
          )

          nil
        end

      {:error, reason} ->
        log_cache_event(
          "Schema cache miss for #{repo}.#{table_name} (not cached: #{inspect(reason)})",
          :debug
        )

        nil
    end
  end

  @spec get_or_infer(module(), String.t()) :: Schema.t()
  def get_or_infer(repo, table_name) do
    case get_cached_schema(repo, table_name) do
      nil ->
        warm_up(repo, table_name)

      schema ->
        schema
    end
  end

  @doc """
  Manually caches a schema for a specific repository and table.

  This function is used to populate the cache after the application starts
  and the database becomes available. It's typically called during application
  startup or after migrations.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_name` - The database table name
  - `schema` - The schema tuple to cache
  """
  @spec cache_schema(module(), String.t(), any()) :: :ok | {:error, term()}
  def cache_schema(repo, table_name, schema) do
    digest = calculate_current_migrations_digest(repo)
    cache_file = get_cache_file_path(repo, table_name)

    cache_data = %{
      "schema" => schema,
      "digest" => digest
    }

    log_cache_event(
      "Caching schema for #{repo}.#{table_name} with digest #{digest} to #{cache_file}",
      :debug
    )

    :ok = write_cache_file(cache_file, cache_data)
    digest_file = get_digest_file_path(repo)
    :ok = write_stored_digest(digest_file, digest)
  end

  @doc """
  Clears all cached schemas for a specific repository.

  This is useful when you know the database structure has changed
  and want to force re-inference for all tables in a repository.

  ## Parameters

  - `repo` - The Ecto repository module to clear cache for

  ## Examples

      Drops.Relation.Cache.clear_repo_cache(MyApp.Repo)
  """
  @spec clear_repo_cache(module()) :: :ok
  def clear_repo_cache(repo) do
    cache_dir = get_repo_cache_dir(repo)

    if File.exists?(cache_dir) do
      File.rm_rf!(cache_dir)
      log_cache_event("Cleared schema cache for repository: #{inspect(repo)}", :info)
    end

    :ok
  end

  @doc """
  Clears the entire schema cache.

  This removes all cached schemas for all repositories.
  """
  @spec clear_all() :: :ok
  def clear_all do
    cache_dir = cache_absolute_directory()

    if File.exists?(cache_dir) do
      File.rm_rf!(cache_dir)
      log_cache_event("Cleared entire schema cache", :info)
    end

    :ok
  end

  @doc """
  Warms up the cache by pre-loading schemas for specified tables.

  This function infers schemas for the given tables and caches the results.
  This can be useful during application startup to ensure frequently used
  schemas are cached.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_names` - List of table names to warm up

  ## Returns

  Returns `:ok` on success, or `{:error, reason}` if warming up fails.

  ## Examples

      # Warm up cache for common tables
      Drops.Relation.Cache.warm_up(MyApp.Repo, ["users", "posts", "comments"])
  """

  @spec warm_up(module(), String.t()) :: Schema.t() | {:error, term()}
  def warm_up(repo, table_name) when is_binary(table_name) do
    case warm_up(repo, [table_name]) do
      {:ok, schemas} -> List.last(schemas)
      err -> err
    end
  end

  @spec warm_up(module(), [String.t()]) :: {:ok, [Schema.t()]} | {:error, term()}
  def warm_up(repo, table_names) when is_atom(repo) and is_list(table_names) do
    schemas =
      Enum.map(table_names, fn table_name ->
        if schema = get_cached_schema(repo, table_name) do
          schema
        else
          schema =
            case Drops.SQL.Database.table(table_name, repo) do
              {:ok, table} ->
                Drops.Relation.Compilers.SchemaCompiler.visit(table, %{})

              {:error, reason} ->
                raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
            end

          cache_schema(repo, table_name, schema)
          schema
        end
      end)

    {:ok, schemas}
  end

  @doc """
  Forces a refresh of cached schemas for a repository.

  This clears the cache for the repository and then optionally warms it up
  again with the specified table names.

  ## Parameters

  - `repo` - The Ecto repository module
  - `table_names` - Optional list of table names to warm up after clearing

  ## Examples

      # Just clear the cache
      Drops.Relation.Cache.refresh(MyApp.Repo)

      # Clear and warm up specific tables
      Drops.Relation.Cache.refresh(MyApp.Repo, ["users", "posts"])
  """
  @spec refresh(module(), [String.t()] | nil) :: :ok | {:error, term()}
  def refresh(repo, table_names \\ nil) when is_atom(repo) do
    clear_repo_cache(repo)

    case table_names do
      nil ->
        :ok

      names when is_list(names) ->
        case warm_up(repo, names) do
          {:ok, _schemas} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  ## Private API

  defp get_migrations_digest(repo) do
    try do
      migrations_dir = get_migrations_dir(repo)

      if File.exists?(migrations_dir) do
        current_digest = calculate_migrations_digest(migrations_dir)
        digest_file = get_digest_file_path(repo)

        # Check if we need to update the stored digest
        stored_digest = read_stored_digest(digest_file)

        if current_digest != stored_digest do
          # Digest has changed, clear cache for this repo and update stored digest
          clear_repo_cache(repo)
          write_stored_digest(digest_file, current_digest)
        end

        current_digest
      else
        # No migrations directory, use empty digest
        "empty"
      end
    rescue
      _ -> "empty"
    end
  end

  defp calculate_current_migrations_digest(repo) do
    try do
      migrations_dir = get_migrations_dir(repo)

      if File.exists?(migrations_dir) do
        calculate_migrations_digest(migrations_dir)
      else
        # No migrations directory, use empty digest
        "empty"
      end
    rescue
      _ -> "empty"
    end
  end

  defp get_migrations_dir(repo) do
    # Get the priv directory for the repo
    priv_dir = repo.config()[:priv] || "priv/repo"
    Path.join([File.cwd!(), priv_dir, "migrations"])
  end

  defp calculate_migrations_digest(migrations_dir) do
    migrations_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".exs"))
    |> Enum.sort()
    |> Enum.map(fn file ->
      file_path = Path.join(migrations_dir, file)
      content = File.read!(file_path)
      {file, :crypto.hash(:sha256, content) |> Base.encode16()}
    end)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16()
  end

  defp get_digest_file_path(repo) do
    cache_dir = cache_absolute_directory()
    repo_name = repo |> Module.split() |> List.last() |> String.downcase()
    Path.join(cache_dir, "#{repo_name}_#{@digest_file_name}")
  end

  defp read_stored_digest(digest_file) do
    case File.read(digest_file) do
      {:ok, content} -> String.trim(content)
      {:error, _} -> nil
    end
  end

  defp write_stored_digest(digest_file, digest) do
    File.write!(digest_file, digest)
  end

  # JSON file handling functions

  @doc """
  Returns the cache file path for a given repo and table name.
  Used by relation modules to register the cache file as an external resource.
  """
  @spec get_cache_file_path(module(), String.t()) :: String.t()
  def get_cache_file_path(repo, table_name) do
    repo_cache_dir = get_repo_cache_dir(repo)
    File.mkdir_p!(repo_cache_dir)
    Path.join(repo_cache_dir, "#{table_name}.json")
  end

  defp get_repo_cache_dir(repo) do
    cache_dir = cache_absolute_directory()
    repo_name = repo |> Module.split() |> List.last() |> String.downcase()
    Path.join(cache_dir, repo_name)
  end

  defp encode(data) do
    JSON.encode!(data)
  end

  defp decode(data) do
    JSON.decode!(data)
  end

  defp read_cache_file(cache_file) do
    case File.read(cache_file) do
      {:ok, content} ->
        {:ok, decode(content)}

      {:error, reason} ->
        {:error, {:file_read, reason}}
    end
  end

  defp write_cache_file(cache_file, data) do
    json = encode(data)
    cache_file |> Path.dirname() |> File.mkdir_p!()
    File.write!(cache_file, json)
    log_cache_event("Cached schema to #{cache_file}", :debug)
    :ok
  end

  defp cache_absolute_directory do
    Path.join(File.cwd!(), cache_relative_dir())
  end

  defp cache_relative_dir do
    Path.join(["tmp", "cache", Mix.env() |> Atom.to_string(), "drops_relation_schema"])
  end

  ## Private Helpers

  # Log cache events to appropriate logger based on environment
  defp log_cache_event(message, level) do
    case Mix.env() do
      :test ->
        # In test environment, log to drops_relation_test logger (file)
        Logger.log(level, message, logger: :drops_relation_test)

      _ ->
        # In other environments, use default logger
        Logger.log(level, message)
    end
  end
end
