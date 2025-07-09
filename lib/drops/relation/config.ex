defmodule Drops.Relation.Config do
  @moduledoc """
  Configuration management for DropsRelation.

  This module provides a centralized configuration system for DropsRelation, handling
  validation, persistence, and runtime access to configuration options.

  ## Configuration

  DropsRelation can be configured through the application environment, under the `:drops_relation` application.
  For example, you can do this in `config/config.exs`:

      # config/config.exs
      config :drops_relation,
        schema_cache: [enabled: true]

  ## Configuration Options

  ### `:schema_cache`

  Configuration for the DropsRelation schema cache.

  **Type:** keyword list
  **Default:** `[enabled: true]`

  ## Examples

      # Basic configuration
      config :drops_relation,
        schema_cache: [enabled: true]

      # Runtime configuration update (not recommended for production)
      DropsRelation.Config.put_config(:schema_cache, enabled: false)
  """

  # Configuration schema definition
  @config_schema [
    schema_cache: [
      type: :keyword_list,
      default: [
        enabled: true
      ],
      keys: [
        enabled: [type: :boolean, default: true]
      ],
      type_doc: "keyword list",
      doc: """
      Configuration for the DropsRelation schema cache.

      ## Options

      - `:enabled` - Whether to enable schema caching (default: true)

      ## Example

          config :drops_relation,
            schema_cache: [
              enabled: true
            ]
      """
    ]
  ]

  @opts_schema NimbleOptions.new!(@config_schema)
  @valid_keys Keyword.keys(@config_schema)

  @doc """
  Validates the current application configuration.

  This function reads the configuration from the `:drops_relation` application environment
  and validates it according to the defined schema.

  ## Returns

  Returns the validated configuration as a keyword list.

  ## Raises

  Raises `ArgumentError` if the configuration is invalid.
  """
  @spec validate!() :: keyword()
  def validate! do
    :drops_relation
    |> Application.get_all_env()
    |> validate!()
  end

  @doc """
  Validates the given configuration.

  ## Parameters

  - `config` - The configuration to validate as a keyword list

  ## Returns

  Returns the validated configuration as a keyword list.

  ## Raises

  Raises `ArgumentError` if the configuration is invalid.
  """
  @spec validate!(keyword()) :: keyword()
  def validate!(config) when is_list(config) do
    config_opts = Keyword.take(config, @valid_keys)

    case NimbleOptions.validate(config_opts, @opts_schema) do
      {:ok, opts} ->
        opts

      {:error, error} ->
        raise ArgumentError, """
        invalid configuration for the :drops_relation application, so we cannot start or update
        its configuration. The error was:

            #{Exception.message(error)}

        See the documentation for the DropsRelation.Config module for more information on configuration.
        """
    end
  end

  @doc """
  Persists the given configuration to `:persistent_term`.

  This function stores each configuration key-value pair in `:persistent_term`
  for efficient runtime access.

  ## Parameters

  - `config` - The validated configuration to persist as a keyword list

  ## Returns

  Returns `:ok`.
  """
  @spec persist(keyword()) :: :ok
  def persist(config) when is_list(config) do
    Enum.each(config, fn {key, value} ->
      :persistent_term.put({:drops_relation_config, key}, value)
    end)
  end

  @doc """
  Gets the schema cache configuration.

  ## Returns

  Returns a keyword list with schema cache configuration options.
  """
  @spec schema_cache() :: keyword()
  def schema_cache, do: fetch!(:schema_cache)

  @doc """
  Updates the value of `key` in the configuration *at runtime*.

  Once the `:drops_relation` application starts, it validates and caches the value of the
  configuration options you start it with. Because of this, updating configuration
  at runtime requires this function as opposed to just changing the application
  environment.

  > #### This Function Is Slow {: .warning}
  >
  > This function updates terms in [`:persistent_term`](`:persistent_term`), which is what
  > this library uses to cache configuration. Updating terms in `:persistent_term` is slow
  > and can trigger full GC sweeps. We recommend only using this function in rare cases,
  > or during tests.

  ## Parameters

  - `key` - The configuration key to update
  - `value` - The new value for the configuration key

  ## Returns

  Returns `:ok`.

  ## Raises

  Raises `ArgumentError` if the key is not a valid configuration option or if the
  value is invalid for the given key.

  ## Examples

      # Update schema cache configuration at runtime (useful for testing)
      DropsRelation.Config.put_config(:schema_cache, enabled: false)
  """
  @spec put_config(atom(), term()) :: :ok
  def put_config(key, value) when is_atom(key) do
    unless key in @valid_keys do
      raise ArgumentError, "unknown option #{inspect(key)}"
    end

    [{key, value}]
    |> validate!()
    |> persist()
  end

  @doc """
  Updates a configuration key with new values.

  For keyword list configurations like `:schema_cache`, this merges the new
  values with the existing configuration.

  ## Parameters

  - `key` - The configuration key to update
  - `value` - The new value or keyword list to merge

  ## Examples

      # Update schema cache configuration
      DropsRelation.Config.update(:schema_cache, enabled: false)
  """
  @spec update(atom(), term()) :: :ok
  def update(key, value) when is_atom(key) do
    unless key in @valid_keys do
      raise ArgumentError, "unknown option #{inspect(key)}"
    end

    current_value = fetch!(key)

    new_value =
      case {current_value, value} do
        {current, new} when is_list(current) and is_list(new) ->
          Keyword.merge(current, new)

        {_current, new} ->
          new
      end

    put_config(key, new_value)
  end

  ## Private functions

  @compile {:inline, fetch!: 1}
  defp fetch!(key) do
    :persistent_term.get({:drops_relation_config, key})
  rescue
    ArgumentError ->
      # Fallback to application environment if persistent term not available
      Application.get_env(:drops_relation, key, get_default(key))
  end

  defp get_default(:schema_cache), do: [enabled: true]
  defp get_default(_key), do: nil
end
