defmodule Drops.Relation.Config do
  alias Drops.Relation.Inflection

  alias __MODULE__

  @moduledoc """
  Centralized configuration management for Drops.Relation.

  This module handles configuration for relation modules, including support for
  function-based configuration values that are evaluated with the relation module
  as a parameter.
  """

  @config_schema [
    repo: [
      type: :atom,
      required: false,
      doc: """
      The Ecto repository module to use for database operations.
      """
    ],
    ecto_schema_namespace: [
      type: {:or, [{:list, {:or, [:atom, :string]}}, {:fun, 1}]},
      default: &Config.default_ecto_schema_namespace/1,
      type_doc: "list of atoms or strings or function/1",
      doc: """
      TODO
      """
    ],
    ecto_schema_module: [
      type: {:or, [:atom, {:fun, 1}]},
      default: &Config.default_ecto_schema_module/1,
      type_doc: "atom or function/1",
      doc: """
      TODO
      """
    ]
  ]

  @opts_schema NimbleOptions.new!(@config_schema)
  @valid_keys Keyword.keys(@config_schema)

  def default_ecto_schema_namespace(relation) do
    String.split(Atom.to_string(relation), ".") ++ ["Schemas"]
  end

  def default_ecto_schema_module(relation) do
    Inflection.module_to_schema_name(relation)
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

        See the documentation for the Drops.Relation.Config module for more information on configuration.
        """
    end
  end

  def persist!(config) when is_list(config) do
    validated = validate!(config)
    :ok = :persistent_term.put(:drops_relation_config, validated)
    validated
  end

  @spec get(atom(), term()) :: term()
  def get(key, default \\ nil) do
    config = :persistent_term.get(:drops_relation_config)
    Keyword.get(config, key, default)
  end
end
