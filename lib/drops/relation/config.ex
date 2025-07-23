defmodule Drops.Relation.Config do
  alias Drops.Relation.Inflector

  alias __MODULE__

  @moduledoc """
  Configuration management for Drops.Relation.

  This module handles configuration for relation modules, including:
  - Default plugin configuration
  - Schema module naming conventions
  - Repository settings
  - Function-based configuration values

  ## Configuration Options

  Configuration can be set at the application level:

      config :my_app, :drops,
        relation: [
          default_plugins: [
            Drops.Relation.Plugins.Schema,
            Drops.Relation.Plugins.Reading,
            Drops.Relation.Plugins.Writing
          ],
          ecto_schema_module: &MyApp.CustomSchemaModule.for_relation/1
        ]

  ## Function-based Configuration

  Configuration values can be functions that receive the relation module as a parameter,
  allowing for dynamic configuration based on the relation being defined.
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
    ],
    view_module: [
      type: {:fun, 1},
      default: &Config.default_view_module/1,
      type_doc: "function/1",
      doc: """
      TODO
      """
    ],
    default_plugins: [
      type: {:or, [{:list, :atom}, {:fun, 1}]},
      default: &Config.default_plugins/1,
      type_doc: "list of atoms or function/1",
      doc: """
      List of plugin modules to use by default when no plugins are explicitly specified.
      Each plugin module should implement the Drops.Relation.Plugin behavior.
      Can be a list of atoms or a function that takes a relation module and returns a list of atoms.
      """
    ]
  ]

  @opts_schema NimbleOptions.new!(@config_schema)
  @valid_keys Keyword.keys(@config_schema)

  def default_ecto_schema_namespace(relation) do
    String.split(Atom.to_string(relation), ".")
  end

  def default_ecto_schema_module(relation) do
    Inflector.classify(relation)
  end

  def default_view_module({relation, name}) do
    Module.concat([relation, Inflector.camelize(name)])
  end

  def default_plugins(_relation) do
    [
      Drops.Relation.Plugins.Schema,
      Drops.Relation.Plugins.Reading,
      Drops.Relation.Plugins.Writing,
      Drops.Relation.Plugins.Loadable,
      Drops.Relation.Plugins.Views,
      Drops.Relation.Plugins.Queryable,
      Drops.Relation.Plugins.AutoRestrict,
      Drops.Relation.Plugins.Pagination,
      Drops.Relation.Plugins.Ecto.Query
    ]
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
