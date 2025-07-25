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

  import Mix.Ecto

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

    # Start the application
    Mix.Task.run("app.start")

    # Get the repository using Mix.Ecto helpers
    repo = get_repo(options, igniter.args.argv)

    # Get list of tables to process
    tables = get_tables_to_process(repo, options)

    if Enum.empty?(tables) do
      Mix.shell().info("No tables found to generate schemas for.")
      igniter
    else
      Mix.shell().info("Generating schemas for tables: #{Enum.join(tables, ", ")}")

      # Generate schema files for each table
      Enum.reduce(tables, igniter, fn table, acc_igniter ->
        generate_schema_file(acc_igniter, table, repo, options)
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
    |> Map.put_new(:sync, true)
  end

  defp get_repo(options, argv) do
    if repo_name = options[:repo] do
      ensure_repo(String.to_atom("Elixir.#{repo_name}"), argv)
    else
      # Use parse_repo to get the default repo
      case parse_repo(argv) do
        [repo | _] -> repo
        [] -> Mix.raise("No repository found. Please specify --repo option.")
      end
    end
  end

  defp get_tables_to_process(repo, options) do
    if tables_option = options[:tables] do
      String.split(tables_option, ",", trim: true)
      |> Enum.map(&String.trim/1)
    else
      # Get all tables from the database
      get_all_tables(repo)
    end
  end

  defp get_all_tables(repo) do
    case Drops.SQL.Database.list_tables(repo) do
      {:ok, tables} ->
        # Filter out schema_migrations table
        Enum.reject(tables, &(&1 == "schema_migrations"))

      {:error, reason} ->
        Mix.shell().error("Failed to list tables from #{inspect(repo)}: #{inspect(reason)}")
        []
    end
  end

  defp generate_schema_file(igniter, table, repo, options) do
    # Build module name
    module_name_string = build_module_name_string(table, options[:namespace])
    module_name = Module.parse(module_name_string)

    # Get or infer the schema
    schema = get_or_infer_schema(repo, table)
    module_ast = Generator.generate_module_content(schema)
    module_content = Macro.to_string(module_ast)

    Mix.shell().info("Creating or updating schema: #{module_name_string}")

    Module.find_and_update_or_create_module(
      igniter,
      module_name,
      module_content,
      fn zipper ->
        if options[:sync] do
          update_schema_preserving_custom_code(zipper, table, repo, options)
        else
          replace_entire_module_content(zipper, module_ast)
        end
      end
    )
  end

  defp get_or_infer_schema(repo, table) do
    case Cache.get_cached_schema(repo, table) do
      nil ->
        # Schema not cached, infer it
        case Drops.SQL.Database.table(table, repo) do
          {:ok, table_struct} ->
            schema = Drops.Relation.Compilers.SchemaCompiler.visit(table_struct, %{})
            Cache.cache_schema(repo, table, schema)
            schema

          {:error, reason} ->
            raise "Failed to introspect table #{table}: #{inspect(reason)}"
        end

      schema ->
        schema
    end
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
  defp update_schema_preserving_custom_code(zipper, table_name, repo, _options) do
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
end
