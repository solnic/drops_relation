defmodule Mix.Tasks.Drops.Relation.GenSchemas do
  @moduledoc """
  Generates Ecto schema files from Drops.Relation inferred schemas.

  This task introspects database tables and generates explicit Ecto schema files
  with field definitions based on the inferred schema metadata.

  ## Usage

      mix drops.relations.gen_schemas [options]

  ## Options

    * `--namespace` - The namespace for generated schemas (e.g., "MyApp.Relations")
    * `--repo` - The Ecto repository module (e.g., "MyApp.Repo")
    * `--app` - The application name to infer defaults from (e.g., "MyApp")
    * `--sync` - Whether to sync/update existing files (default: true)
    * `--tables` - Comma-separated list of specific tables to generate schemas for

  ## Examples

      # Generate schemas for all tables with default settings
      mix drops.relations.gen_schemas --app MyApp

      # Generate schemas with custom namespace
      mix drops.relations.gen_schemas --namespace MyApp.Schemas --app MyApp

      # Generate schemas for specific tables only
      mix drops.relations.gen_schemas --tables users,posts --app MyApp

      # Overwrite existing files instead of syncing
      mix drops.relations.gen_schemas --app MyApp --sync false
  """

  use Igniter.Mix.Task

  alias Drops.Relation.Cache
  alias Drops.Relation.Generator
  alias Igniter.Project.Module

  require Sourceror.Zipper

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :drops_relation,
      example: "mix drops.relations.gen_schemas --app MyApp",
      positional: [],
      schema: [
        namespace: :string,
        repo: :string,
        app: :string,
        sync: :boolean,
        tables: :string,
        help: :boolean
      ],
      aliases: [
        n: :namespace,
        r: :repo,
        a: :app,
        s: :sync,
        t: :tables,
        h: :help
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    options = validate_and_parse_options(igniter.args.argv)

    # Make Igniter non-interactive for testing
    igniter =
      igniter
      |> Igniter.assign(:prompt_on_git_changes?, false)
      |> Igniter.assign(:quiet_on_no_changes?, true)

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
    # Build module name
    module_name_string = build_module_name_string(table, options[:namespace])
    module_name = Module.parse(module_name_string)
    repo = String.to_existing_atom("Elixir.#{options[:repo]}")

    module_ast = Generator.generate_module_content(Cache.get_cached_schema(repo, table))
    module_content = Macro.to_string(module_ast)

    Mix.shell().info("Creating or updating schema: #{module_name_string}")

    Module.find_and_update_or_create_module(
      igniter,
      module_name,
      module_content,
      fn zipper ->
        if options[:sync] do
          update_schema_preserving_custom_code(zipper, table, module_name_string, options)
        else
          replace_entire_module_content(zipper, module_ast)
        end
      end
    )
  end

  defp build_module_name_string(table, namespace) do
    table_module = table |> Macro.camelize()
    "#{namespace}.#{table_module}"
  end

  # Helper function for non-sync mode: replace entire module content
  defp replace_entire_module_content(zipper, schema_content) do
    case Code.string_to_quoted(schema_content) do
      {:ok, new_ast} ->
        {:ok, Sourceror.Zipper.replace(zipper, new_ast)}

      {:error, _} ->
        :error
    end
  end

  # Helper function for sync mode: preserve custom code and only update schema-related parts
  defp update_schema_preserving_custom_code(zipper, table_name, _module_name_string, options) do
    repo_name = options[:repo]
    repo = ensure_repo_started(repo_name)

    # Get fresh schema data
    drops_relation_schema =
      case Drops.SQL.Database.table(table_name, repo) do
        {:ok, table_struct} ->
          Drops.Relation.Compilers.SchemaCompiler.visit(table_struct, %{})

        {:error, reason} ->
          raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
      end

    # Use Generator for schema patching
    updated_zipper =
      Generator.update_schema_with_zipper(zipper, table_name, drops_relation_schema)

    {:ok, updated_zipper}
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

  # Ensures the repository module is loaded and started.
  # Returns the repository module atom.
  # Raises RuntimeError if the repository cannot be started.
  @spec ensure_repo_started(String.t()) :: module()
  defp ensure_repo_started(repo_name) do
    repo_module = String.to_atom("Elixir.#{repo_name}")

    # Ensure the module is loaded
    case Code.ensure_loaded(repo_module) do
      {:module, ^repo_module} ->
        # Try to start the repo if it's not already started
        case repo_module.__adapter__() do
          adapter when is_atom(adapter) ->
            # Ensure the application is started
            case Application.ensure_all_started(:ecto_sql) do
              {:ok, _} ->
                # Check if repo is started, if not try to start it
                case GenServer.whereis(repo_module) do
                  nil ->
                    # Try to start the repo
                    case repo_module.start_link() do
                      {:ok, _pid} ->
                        repo_module

                      {:error, {:already_started, _pid}} ->
                        repo_module

                      {:error, reason} ->
                        raise RuntimeError,
                              "Failed to start repository #{repo_name}: #{inspect(reason)}"
                    end

                  _pid ->
                    repo_module
                end

              {:error, reason} ->
                raise RuntimeError,
                      "Failed to start :ecto_sql application: #{inspect(reason)}"
            end

          _ ->
            raise RuntimeError, "Repository #{repo_name} does not have a valid adapter"
        end

      {:error, reason} ->
        raise RuntimeError,
              "could not lookup Ecto repo #{repo_name} because it was not started or it does not exist: #{inspect(reason)}"
    end
  end
end
