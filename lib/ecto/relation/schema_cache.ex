defmodule Ecto.Relation.SchemaCache do
  @moduledoc """
  Persistent cache for inferred Ecto.Relation schemas based on migration file digests.

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
      Ecto.Relation.SchemaCache.cache_schema(MyApp.Repo, "users", schema)

      # Get cached schema (returns nil if not cached)
      schema = Ecto.Relation.SchemaCache.get_cached_schema(MyApp.Repo, "users")

      # Clear cache for a specific repository
      Ecto.Relation.SchemaCache.clear_repo_cache(MyApp.Repo)

      # Get cached schema or empty schema if not cached
      schema = Ecto.Relation.SchemaCache.maybe_get_cached_schema(MyApp.Repo, "users")

      # Check if cache is enabled
      if Ecto.Relation.SchemaCache.enabled?() do
        # Cache-specific logic
      end

      # Warm up cache for specific tables
      Ecto.Relation.SchemaCache.warm_up(MyApp.Repo, ["users", "posts", "comments"])
  """

  require Logger

  alias Ecto.Relation.Config
  alias Ecto.Relation.Schema

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
  @spec get_cached_schema(module(), String.t()) :: any() | nil
  def get_cached_schema(repo, table_name) do
    current_digest = get_migrations_digest(repo)
    cache_file = get_cache_file_path(repo, table_name)

    case read_cache_file(cache_file) do
      {:ok, %{"schema" => schema_data, "digest" => stored_digest}} ->
        if current_digest == stored_digest do
          log_cache_event("Schema cache hit for #{repo}.#{table_name}", :debug)
          deserialize_schema(schema_data)
        else
          # Digest mismatch, cache is stale
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

  ## Examples

      schema = Ecto.Relation.Inference.infer_schema(relation, "users", MyApp.Repo)
      Ecto.Relation.SchemaCache.cache_schema(MyApp.Repo, "users", schema)
  """
  @spec cache_schema(module(), String.t(), any()) :: :ok
  def cache_schema(repo, table_name, schema) do
    if cache_enabled?() do
      # Calculate digest without triggering cache clearing
      digest = calculate_current_migrations_digest(repo)
      cache_file = get_cache_file_path(repo, table_name)

      cache_data = %{
        "schema" => serialize_schema(schema),
        "digest" => digest
      }

      log_cache_event(
        "Caching schema for #{repo}.#{table_name} with digest #{digest} to #{cache_file}",
        :debug
      )

      write_cache_file(cache_file, cache_data)

      # Update the stored digest file to match
      digest_file = get_digest_file_path(repo)
      write_stored_digest(digest_file, digest)
    else
      log_cache_event(
        "Cache disabled, not caching schema for #{repo}.#{table_name}",
        :debug
      )
    end

    :ok
  end

  @doc """
  Clears all cached schemas for a specific repository.

  This is useful when you know the database structure has changed
  and want to force re-inference for all tables in a repository.

  ## Parameters

  - `repo` - The Ecto repository module to clear cache for

  ## Examples

      Ecto.Relation.SchemaCache.clear_repo_cache(MyApp.Repo)
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
  Checks if schema caching is enabled.

  ## Returns

  Returns `true` if caching is enabled, `false` otherwise.

  ## Examples

      if Ecto.Relation.SchemaCache.enabled?() do
        IO.puts("Cache is enabled")
      end
  """
  @spec enabled?() :: boolean()
  def enabled? do
    Config.schema_cache()[:enabled]
  end

  @doc """
  Returns the current cache configuration.

  ## Returns

  A keyword list with the current cache configuration.

  ## Examples

      config = Ecto.Relation.SchemaCache.config()
      # => [enabled: true]
  """
  @spec config() :: keyword()
  def config do
    Config.schema_cache()
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
      Ecto.Relation.SchemaCache.warm_up(MyApp.Repo, ["users", "posts", "comments"])
  """

  @spec warm_up(module(), String.t()) :: Schema.t() | {:error, term()}
  def warm_up(repo, table_name) when is_binary(table_name) do
    case warm_up(repo, [table_name]) do
      {:ok, schemas} -> List.last(schemas)
      err -> err
    end
  end

  @spec warm_up(module(), [String.t()]) :: :ok | {:error, term()}
  def warm_up(repo, table_names) when is_atom(repo) and is_list(table_names) do
    try do
      schemas =
        Enum.map(table_names, fn table_name ->
          if schema = get_cached_schema(repo, table_name) do
            schema
          else
            schema = Ecto.Relation.SQL.Inference.infer_from_table(table_name, repo)
            cache_schema(repo, table_name, schema)
            schema
          end
        end)

      {:ok, schemas}
    rescue
      error -> {:error, error}
    end
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
      Ecto.Relation.SchemaCache.refresh(MyApp.Repo)

      # Clear and warm up specific tables
      Ecto.Relation.SchemaCache.refresh(MyApp.Repo, ["users", "posts"])
  """
  @spec refresh(module(), [String.t()] | nil) :: :ok | {:error, term()}
  def refresh(repo, table_names \\ nil) when is_atom(repo) do
    clear_repo_cache(repo)

    case table_names do
      nil -> :ok
      names when is_list(names) -> warm_up(repo, names)
    end
  end

  # Test helper functions - only available in test environment
  if Mix.env() == :test do
    @doc false
    def test_deserialize_field(data), do: deserialize_field(data)

    @doc false
    def test_serialize_schema(schema), do: serialize_schema(schema)

    @doc false
    def test_deserialize_schema(data), do: deserialize_schema(data)
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

  defp read_cache_file(cache_file) do
    case File.read(cache_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, {:json_decode, reason}}
        end

      {:error, reason} ->
        {:error, {:file_read, reason}}
    end
  end

  defp write_cache_file(cache_file, data) do
    try do
      case Jason.encode(data) do
        {:ok, json} ->
          File.write!(cache_file, json)
          log_cache_event("Cached schema to #{cache_file}", :debug)

        {:error, reason} ->
          log_cache_event("Failed to encode schema to JSON: #{inspect(reason)}", :warning)
      end
    rescue
      error ->
        log_cache_event("Exception writing cache file: #{inspect(error)}", :warning)
    end
  end

  defp serialize_schema(%{__struct__: _} = schema) do
    # Convert the schema struct to a map that can be JSON-encoded
    schema
    |> Map.from_struct()
    |> Enum.into(%{}, fn {key, value} ->
      {to_string(key), serialize_value(value)}
    end)
  end

  defp serialize_schema(schema) do
    # Handle non-struct values (like atoms used in tests)
    serialize_value(schema)
  end

  defp deserialize_schema(schema_data) when is_map(schema_data) do
    # Check if this looks like a Schema struct data
    if Map.has_key?(schema_data, "source") do
      # Convert the map back to a Schema struct
      fields = %{
        source: schema_data["source"],
        primary_key: deserialize_primary_key(schema_data["primary_key"]),
        foreign_keys: deserialize_foreign_keys(schema_data["foreign_keys"]),
        fields: deserialize_fields(schema_data["fields"]),
        indices: deserialize_indices(schema_data["indices"])
      }

      struct(Schema, fields)
    else
      # Handle other map data
      schema_data
    end
  end

  defp deserialize_schema(schema_data) when is_binary(schema_data) do
    # Handle atom strings (from test data)
    String.to_atom(schema_data)
  end

  defp deserialize_schema(schema_data) do
    # Handle other data types (like atoms, numbers, etc.)
    schema_data
  end

  defp serialize_value(nil), do: nil
  defp serialize_value(true), do: true
  defp serialize_value(false), do: false
  defp serialize_value(value) when is_atom(value), do: to_string(value)
  defp serialize_value(value) when is_list(value), do: Enum.map(value, &serialize_value/1)
  defp serialize_value(%{__struct__: _} = struct), do: serialize_struct(struct)

  defp serialize_value(value) when is_map(value) do
    Enum.into(value, %{}, fn {k, v} -> {serialize_value(k), serialize_value(v)} end)
  end

  defp serialize_value(value), do: value

  defp serialize_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.put("__struct__", struct.__struct__ |> Module.split() |> List.last())
    |> Enum.into(%{}, fn {key, value} ->
      {to_string(key), serialize_value(value)}
    end)
  end

  # Deserialization functions

  defp deserialize_primary_key(nil), do: nil

  defp deserialize_primary_key(data) when is_map(data) do
    fields = deserialize_fields(data["fields"] || [])
    %Ecto.Relation.Schema.PrimaryKey{fields: fields}
  end

  defp deserialize_foreign_keys(nil), do: []

  defp deserialize_foreign_keys(data) when is_list(data) do
    Enum.map(data, &deserialize_foreign_key/1)
  end

  defp deserialize_foreign_key(data) when is_map(data) do
    %Ecto.Relation.Schema.ForeignKey{
      field: String.to_atom(data["field"]),
      references_table: data["references_table"],
      references_field: String.to_atom(data["references_field"]),
      association_name: data["association_name"] && String.to_atom(data["association_name"])
    }
  end

  defp deserialize_fields(nil), do: []

  defp deserialize_fields(data) when is_list(data) do
    Enum.map(data, &deserialize_field/1)
  end

  defp deserialize_field(data) when is_map(data) do
    %Ecto.Relation.Schema.Field{
      name: String.to_atom(data["name"]),
      type: deserialize_ecto_type(data["type"]),
      ecto_type: deserialize_ecto_type(data["ecto_type"]),
      source: String.to_atom(data["source"]),
      meta: deserialize_meta(data["meta"])
    }
  end

  defp deserialize_ecto_type(type) when is_binary(type), do: String.to_atom(type)

  defp deserialize_ecto_type(type) when is_list(type) do
    # Handle tuples that were serialized as lists (e.g., {:array, :string} -> ["array", "string"])
    case type do
      [first | rest] when is_binary(first) ->
        # Convert list of strings back to tuple of atoms
        [String.to_atom(first) | Enum.map(rest, &deserialize_ecto_type/1)]
        |> List.to_tuple()

      _ ->
        # Handle other list cases
        Enum.map(type, &deserialize_ecto_type/1)
    end
  end

  defp deserialize_ecto_type(type) when is_map(type) do
    # Handle complex ecto types that were serialized as maps
    # e.g., {:array, :string} gets serialized as %{"array" => "string"}
    case type do
      %{"array" => element_type} ->
        {:array, deserialize_ecto_type(element_type)}

      %{"map" => value_type} ->
        {:map, deserialize_ecto_type(value_type)}

      # Handle other map-based ecto types as needed
      other_map ->
        # Convert map keys and values back to atoms/proper types
        Enum.into(other_map, %{}, fn {k, v} ->
          {deserialize_ecto_type(k), deserialize_ecto_type(v)}
        end)
    end
  end

  defp deserialize_ecto_type(type), do: type

  defp deserialize_meta(nil), do: %{}

  defp deserialize_meta(data) when is_map(data) do
    data
    |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)
  end

  defp deserialize_indices(nil), do: %Ecto.Relation.Schema.Indices{indices: []}

  defp deserialize_indices(data) when is_map(data) do
    indices = deserialize_index_list(data["indices"] || [])
    %Ecto.Relation.Schema.Indices{indices: indices}
  end

  defp deserialize_index_list(data) when is_list(data) do
    Enum.map(data, &deserialize_index/1)
  end

  defp deserialize_index(data) when is_map(data) do
    %Ecto.Relation.Schema.Index{
      name: data["name"],
      fields: deserialize_index_fields(data["fields"] || []),
      unique: data["unique"] || false
    }
  end

  defp deserialize_index_fields(fields) when is_list(fields) do
    Enum.map(fields, fn
      field when is_binary(field) -> String.to_atom(field)
      field when is_map(field) -> deserialize_field(field)
      field -> field
    end)
  end

  defp cache_enabled? do
    try do
      Config.schema_cache()[:enabled]
    rescue
      # Handle case when Drops application isn't started during compilation
      _ -> false
    end
  end

  defp cache_absolute_directory do
    Path.join(File.cwd!(), cache_relative_dir())
  end

  defp cache_relative_dir do
    Path.join(["tmp", "cache", Mix.env() |> Atom.to_string(), "ecto_relation_schema"])
  end

  ## Private Helpers

  # Log cache events to appropriate logger based on environment
  defp log_cache_event(message, level) do
    case Mix.env() do
      :test ->
        # In test environment, log to ecto_relation_test logger (file)
        Logger.log(level, message, logger: :ecto_relation_test)

      _ ->
        # In other environments, use default logger
        Logger.log(level, message)
    end
  end
end
