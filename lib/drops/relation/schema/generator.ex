defmodule Drops.Relation.Schema.Generator do
  @moduledoc """
  Generates Ecto schema module content from database table introspection.

  This module handles the conversion of database table metadata into
  properly formatted Ecto schema definitions with field types, primary keys,
  and other schema attributes.
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Compilers.CodeCompiler

  require Logger

  @doc """
  Generates a complete Ecto schema module as AST.

  ## Parameters

  - `table_name` - The database table name
  - `module_name` - The full module name for the schema
  - `options` - Generation options including repo and other settings

  ## Returns

  A quoted expression containing the complete Ecto schema module definition.

  ## Examples

      iex> Generator.generate_schema_module("users", "MyApp.Relations.User", %{repo: "MyApp.Repo"})
      {:defmodule, [], [...]}
  """
  @spec generate_schema_module(String.t(), String.t() | atom(), map()) :: Macro.t()
  def generate_schema_module(table_name, module_name, options) do
    repo_name = options[:repo]

    # Ensure the repo module is loaded and started
    repo = ensure_repo_started(repo_name)

    # Use Database.table to get SQL Database Table struct, then compile to Relation Schema
    drops_relation_schema =
      case Drops.SQL.Database.table(table_name, repo) do
        {:ok, table} ->
          Drops.Relation.Compilers.SchemaCompiler.visit(table, [])

        {:error, reason} ->
          raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
      end

    generate_module_content(module_name, table_name, drops_relation_schema)
  end

  @doc """
  Generates the module content from a Drops.Relation.Schema struct.

  ## Parameters

  - `module_name` - The full module name
  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct with metadata

  ## Returns

  A quoted expression containing the module definition.
  """
  @spec generate_module_content(String.t() | atom(), String.t(), Schema.t()) :: Macro.t()
  def generate_module_content(module_name, table_name, schema) do
    # Convert module_name to proper AST representation
    module_ast =
      if is_binary(module_name) do
        # Parse the module name string into proper AST
        module_name
        |> String.split(".")
        |> Enum.map(&String.to_atom/1)
        |> case do
          [single] -> single
          parts -> {:__aliases__, [], parts}
        end
      else
        module_name
      end

    # Use CodeCompiler to generate field definitions and attributes
    compiled_asts = CodeCompiler.visit(schema, [])

    # Separate attributes from field definitions
    {attributes, field_definitions} =
      Enum.split_with(compiled_asts, fn ast ->
        case ast do
          {:@, _, _} -> true
          _ -> false
        end
      end)

    # Create the schema block with field definitions and timestamps
    schema_ast =
      quote do
        schema unquote(table_name) do
          unquote_splicing(field_definitions)
          timestamps()
        end
      end

    # Generate the complete module
    quote do
      defmodule unquote(module_ast) do
        use Ecto.Schema
        import Ecto.Schema
        unquote_splicing(attributes)
        unquote(schema_ast)
      end
    end
  end

  @doc """
  Generates a complete Ecto schema module as a string for backward compatibility.

  ## Parameters

  - `table_name` - The database table name
  - `module_name` - The full module name for the schema
  - `options` - Generation options including repo and other settings

  ## Returns

  A string containing the complete Ecto schema module definition.

  ## Examples

      iex> Generator.generate_schema_module_string("users", "MyApp.Relations.User", %{repo: "MyApp.Repo"})
      "defmodule MyApp.Relations.User do\\n  use Ecto.Schema\\n\\n  schema \\"users\\" do\\n..."
  """
  @spec generate_schema_module_string(String.t(), String.t() | atom(), map()) :: String.t()
  def generate_schema_module_string(table_name, module_name, options) do
    ast = generate_schema_module(table_name, module_name, options)
    Macro.to_string(ast)
  end

  @doc """
  Syncs an existing schema file with new field definitions.

  This function attempts to merge new field definitions into an existing
  schema file while preserving custom code and associations.

  ## Parameters

  - `existing_content` - The current content of the schema file
  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct with new metadata

  ## Returns

  A string containing the updated module content.
  """
  @spec sync_schema_content(String.t(), String.t(), Schema.t()) :: String.t()
  def sync_schema_content(existing_content, table_name, schema) do
    # For now, this is a simplified implementation that replaces the entire schema block
    # A more sophisticated implementation would parse the AST and merge selectively

    # Extract module name from existing content
    module_name = extract_module_name(existing_content)

    if module_name do
      ast = generate_module_content(module_name, table_name, schema)
      Macro.to_string(ast)
    else
      # Fallback if we can't parse the module name
      existing_content
    end
  end

  @doc """
  Extracts the module name from existing schema file content.

  ## Parameters

  - `content` - The file content as a string

  ## Returns

  The module name as a string, or nil if not found.
  """
  @spec extract_module_name(String.t()) :: String.t() | nil
  def extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/, content) do
      [_, module_name] -> module_name
      _ -> nil
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
                        Logger.debug("Started repository #{repo_name}")
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
