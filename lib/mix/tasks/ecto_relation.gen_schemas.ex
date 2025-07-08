defmodule Mix.Tasks.Ecto.Relation.GenSchemas do
  @moduledoc """
  Generates Ecto schema files from Ecto.Relation inferred schemas.

  This task introspects database tables and generates explicit Ecto schema files
  with field definitions based on the inferred schema metadata.

  ## Usage

      mix drops.relations.gen_schemas [options]

  ## Options

    * `--namespace` - The namespace for generated schemas (e.g., "MyApp.Relations")
    * `--dir` - Directory to place generated files (inferred from namespace if not provided)
    * `--repo` - The Ecto repository module (e.g., "MyApp.Repo")
    * `--app` - The application name to infer defaults from (e.g., "MyApp")
    * `--sync` - Whether to sync/update existing files (default: true)
    * `--tables` - Comma-separated list of specific tables to generate schemas for

  ## Examples

      # Generate schemas for all tables with default settings
      mix drops.relations.gen_schemas --app MyApp

      # Generate schemas with custom namespace and directory
      mix drops.relations.gen_schemas --namespace MyApp.Schemas --dir lib/my_app/schemas

      # Generate schemas for specific tables only
      mix drops.relations.gen_schemas --tables users,posts --app MyApp

      # Overwrite existing files instead of syncing
      mix drops.relations.gen_schemas --app MyApp --sync false
  """

  use Igniter.Mix.Task

  alias Igniter.Project.Module
  alias Ecto.Relation.Schema.Generator

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :ecto_relation,
      example: "mix drops.relations.gen_schemas --app MyApp",
      positional: [],
      schema: [
        namespace: :string,
        dir: :string,
        repo: :string,
        app: :string,
        sync: :boolean,
        tables: :string,
        help: :boolean
      ],
      aliases: [
        n: :namespace,
        d: :dir,
        r: :repo,
        a: :app,
        s: :sync,
        t: :tables,
        h: :help
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter, argv) do
    options = validate_and_parse_options(argv)

    # Ensure the application is started before proceeding
    ensure_application_started(options[:app])

    # Get list of tables to process
    tables = get_tables_to_process(options)

    if Enum.empty?(tables) do
      Mix.shell().info("No tables found to generate schemas for.")
      igniter
    else
      Mix.shell().info("Generating schemas for tables: #{Enum.join(tables, ", ")}")

      # Generate schema files for each table
      Enum.reduce(tables, igniter, fn table, acc_igniter ->
        generate_schema_file(acc_igniter, table, options)
      end)
    end
  end

  # Private functions

  defp validate_and_parse_options(argv) do
    {parsed, _remaining, _invalid} =
      OptionParser.parse(argv,
        strict: [
          namespace: :string,
          dir: :string,
          repo: :string,
          app: :string,
          sync: :boolean,
          tables: :string,
          help: :boolean
        ]
      )

    options = Map.new(parsed)

    # Handle help option
    if options[:help] do
      Mix.shell().info(@moduledoc)
      System.halt(0)
    end

    # Validate required options
    unless options[:app] do
      Mix.raise("--app option is required")
    end

    # Set defaults based on app name
    app_name = options[:app]
    namespace = options[:namespace] || "#{app_name}.Relations"

    options
    |> Map.put(:namespace, namespace)
    |> Map.put_new(:repo, "#{app_name}.Repo")
    |> Map.put_new(:sync, true)
    |> Map.put_new(:dir, namespace_to_dir(namespace))
  end

  defp namespace_to_dir(namespace) do
    namespace
    |> String.split(".")
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> then(&Path.join("lib", &1))
  end

  defp get_tables_to_process(options) do
    if tables_option = options[:tables] do
      String.split(tables_option, ",", trim: true)
      |> Enum.map(&String.trim/1)
    else
      # Get all tables from the database
      get_all_tables(options[:repo])
    end
  end

  defp get_all_tables(repo_name) do
    try do
      repo = String.to_existing_atom("Elixir.#{repo_name}")

      # Use database introspection to get table names
      case repo.__adapter__() do
        Ecto.Adapters.SQLite3 ->
          get_sqlite_tables(repo)

        Ecto.Adapters.Postgres ->
          get_postgres_tables(repo)

        _ ->
          Mix.shell().error("Unsupported database adapter for table introspection")
          []
      end
    rescue
      error ->
        Mix.shell().error("Failed to introspect database tables: #{inspect(error)}")
        []
    end
  end

  defp get_sqlite_tables(repo) do
    query =
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'schema_migrations'"

    case repo.query(query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [table_name] -> table_name end)

      {:error, _} ->
        []
    end
  end

  defp get_postgres_tables(repo) do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename != 'schema_migrations'
    """

    case repo.query(query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [table_name] -> table_name end)

      {:error, _} ->
        []
    end
  end

  defp generate_schema_file(igniter, table, options) do
    module_name = build_module_name(table, options[:namespace])
    file_path = build_file_path(table, options[:dir])

    try do
      # Generate the schema content using the new Generator module
      schema_content = Generator.generate_schema_module(table, module_name, options)

      if options[:sync] and File.exists?(file_path) do
        # Sync/update existing file
        sync_existing_schema(igniter, file_path, schema_content, module_name)
      else
        # Create new file or overwrite
        create_new_schema(igniter, file_path, schema_content, module_name)
      end
    rescue
      error ->
        Mix.shell().error(
          "Failed to generate schema for table '#{table}': #{inspect(error)}"
        )

        igniter
    end
  end

  defp build_module_name(table, namespace) do
    table_module = table |> Macro.camelize()
    module_name_string = "#{namespace}.#{table_module}"
    String.to_atom("Elixir.#{module_name_string}")
  end

  defp build_file_path(table, dir) do
    filename = "#{Macro.underscore(table)}.ex"
    Path.join(dir, filename)
  end

  defp sync_existing_schema(igniter, file_path, schema_content, module_name) do
    # For sync mode, we need to update the existing file
    Mix.shell().info("Syncing existing schema: #{module_name}")

    try do
      # For now, use the same approach as create_new_schema
      # A more sophisticated sync would preserve custom code and only update fields
      create_new_schema(igniter, file_path, schema_content, module_name)
    rescue
      error ->
        Mix.shell().error("Failed to sync schema #{module_name}: #{inspect(error)}")
        # Fallback to creating new file
        create_new_schema(igniter, file_path, schema_content, module_name)
    end
  end

  defp create_new_schema(igniter, file_path, schema_content, module_name) do
    Mix.shell().info("Creating new schema: #{module_name}")

    # Create the module using Igniter
    Module.create_module(igniter, module_name, schema_content, path: file_path)
  end

  # Ensures the application is started before running the task
  defp ensure_application_started(app_name) do
    app_atom = String.to_atom(Macro.underscore(app_name))

    case Application.ensure_all_started(app_atom) do
      {:ok, _} ->
        Mix.shell().info("Started application #{app_name}")
        :ok

      {:error, {failed_app, reason}} ->
        Mix.shell().error("Failed to start application #{failed_app}: #{inspect(reason)}")
        Mix.raise("Cannot proceed without starting the application")
    end
  end
end
