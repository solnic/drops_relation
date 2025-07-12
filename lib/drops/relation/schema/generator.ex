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
          Drops.Relation.Compilers.SchemaCompiler.visit(table, %{})

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
    compiled_asts = CodeCompiler.visit(schema, %{})

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
    schema_module(module_ast, schema_ast, attributes)
  end

  def schema_module(module_name, schema_ast, attributes \\ []) do
    quote do
      defmodule unquote(module_name) do
        use Ecto.Schema
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
  Generates just the module body content (without defmodule wrapper) for use with Igniter.

  ## Parameters

  - `table_name` - The database table name
  - `module_name` - The full module name for the schema
  - `options` - Generation options including repo and other settings

  ## Returns

  A string containing just the module body content.

  ## Examples

      iex> Generator.generate_schema_module_body("users", "MyApp.Relations.User", %{repo: "MyApp.Repo"})
      "use Ecto.Schema\\n\\nschema \\"users\\" do\\n..."
  """
  @spec generate_schema_module_body(String.t(), String.t() | atom(), map()) :: String.t()
  def generate_schema_module_body(table_name, _module_name, options) do
    repo_name = options[:repo]

    # Ensure the repo module is loaded and started
    repo = ensure_repo_started(repo_name)

    # Use Database.table to get SQL Database Table struct, then compile to Relation Schema
    drops_relation_schema =
      case Drops.SQL.Database.table(table_name, repo) do
        {:ok, table} ->
          Drops.Relation.Compilers.SchemaCompiler.visit(table, %{})

        {:error, reason} ->
          raise "Failed to introspect table #{table_name}: #{inspect(reason)}"
      end

    generate_module_body_content(table_name, drops_relation_schema)
  end

  @doc """
  Generates just the module body content from a Drops.Relation.Schema struct.

  ## Parameters

  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct with metadata

  ## Returns

  A string containing just the module body content.
  """
  @spec generate_module_body_content(String.t(), Schema.t()) :: String.t()
  def generate_module_body_content(table_name, schema) do
    # Use the new helper function to get schema parts
    parts = generate_schema_parts(table_name, schema)

    # Collect all attributes in the proper order
    all_attributes =
      parts.attributes.primary_key ++
        parts.attributes.foreign_key_type ++
        parts.attributes.other

    # Generate the module body (without defmodule wrapper)
    body_ast =
      quote do
        use Ecto.Schema
        unquote_splicing(all_attributes)
        unquote(parts.schema_ast)
      end

    Macro.to_string(body_ast)
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

  @doc """
  Generates a temporary Ecto schema module from a Drops.Relation.Schema struct.

  This function creates a temporary module that can be used for schema merging
  or other operations that require an actual Ecto.Schema module.

  ## Parameters

  - `module_name` - The module name (atom) for the temporary schema
  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct

  ## Returns

  The module atom of the created temporary schema.

  ## Examples

      iex> schema = %Drops.Relation.Schema{...}
      iex> Generator.generate_temporary_schema_module(TempSchema, "users", schema)
      TempSchema
  """
  @spec generate_temporary_schema_module(atom(), String.t(), Schema.t()) :: atom()
  def generate_temporary_schema_module(module_name, table_name, schema) do
    # Generate the schema AST without defmodule wrapper
    schema_ast = generate_schema_ast_from_schema(table_name, schema)

    # Create the complete module AST
    module_ast =
      quote do
        defmodule unquote(module_name) do
          use Ecto.Schema
          unquote(schema_ast)
        end
      end

    # Compile and load the module
    Code.eval_quoted(module_ast)

    module_name
  end

  @doc """
  Generates schema parts (attributes and field definitions) from a Drops.Relation.Schema struct.

  This function provides access to the individual components of a schema
  without wrapping them in a module definition.

  ## Parameters

  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct

  ## Returns

  A map containing:
  - `:attributes` - Categorized attributes (primary_key, foreign_key_type, other)
  - `:field_definitions` - List of field definition AST nodes
  - `:schema_ast` - The complete schema block AST

  ## Examples

      iex> schema = %Drops.Relation.Schema{...}
      iex> parts = Generator.generate_schema_parts("users", schema)
      iex> %{attributes: _, field_definitions: _, schema_ast: _} = parts
  """
  @spec generate_schema_parts(String.t(), Schema.t()) :: map()
  def generate_schema_parts(table_name, schema) do
    # Use enhanced CodeCompiler with grouped output
    compiled_parts = CodeCompiler.visit(schema, %{grouped: true})

    # Extract categorized attributes and field definitions
    attributes = compiled_parts.attributes
    field_definitions = compiled_parts.field_definitions

    # Create the schema AST
    schema_ast = generate_schema_ast_from_parts(table_name, field_definitions, schema)

    %{
      attributes: attributes,
      field_definitions: field_definitions,
      schema_ast: schema_ast
    }
  end

  @doc """
  Generates just the schema AST block from a Drops.Relation.Schema struct.

  ## Parameters

  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct

  ## Returns

  The schema block AST.
  """
  @spec generate_schema_ast_from_schema(String.t(), Schema.t()) :: Macro.t()
  def generate_schema_ast_from_schema(table_name, schema) do
    # Use enhanced CodeCompiler with grouped output
    compiled_parts = CodeCompiler.visit(schema, %{grouped: true})

    # Extract field definitions and attributes
    attributes = compiled_parts.attributes
    field_definitions = compiled_parts.field_definitions

    # Collect all attributes in the proper order
    all_attributes =
      attributes.primary_key ++
        attributes.foreign_key_type ++
        attributes.other

    # Create the schema block with field definitions and timestamps
    # Use qualified schema call to avoid ambiguity with Drops.Relation.schema/2
    schema_ast = generate_schema_ast_from_parts(table_name, field_definitions, schema, true)

    # Add attributes if needed
    if all_attributes != [] do
      quote location: :keep do
        (unquote_splicing(all_attributes))
        unquote(schema_ast)
      end
    else
      schema_ast
    end
  end

  @doc """
  Merges an inferred schema with custom schema definitions without creating temporary modules.

  This function provides a simpler alternative to the temporary module approach by
  directly converting custom schema definitions to a Drops.Relation.Schema struct
  and merging it with the inferred schema.

  ## Parameters

  - `inferred_schema` - The Drops.Relation.Schema struct from database introspection
  - `custom_schema_definitions` - List of custom schema definitions from the relation macro
  - `table_name` - The database table name

  ## Returns

  A merged Drops.Relation.Schema struct with custom definitions taking precedence.

  ## Examples

      iex> inferred = %Drops.Relation.Schema{...}
      iex> custom_defs = [{:users, quote(do: field(:status, :string))}]
      iex> merged = Generator.merge_schemas_directly(inferred, custom_defs, "users")
      iex> %Drops.Relation.Schema{} = merged
  """
  @spec merge_schemas_directly(Schema.t(), list(), String.t()) :: Schema.t()
  def merge_schemas_directly(inferred_schema, custom_schema_definitions, table_name) do
    # Convert custom schema definitions to a Drops.Relation.Schema struct
    custom_schema = convert_custom_definitions_to_schema(custom_schema_definitions, table_name)

    # Normalize sources to ensure they match (convert to atom)
    normalized_inferred = %{inferred_schema | source: normalize_source(inferred_schema.source)}
    normalized_custom = %{custom_schema | source: normalize_source(custom_schema.source)}

    # Merge the schemas (custom takes precedence)
    Schema.merge(normalized_inferred, normalized_custom)
  end

  # Helper to normalize source to atom
  defp normalize_source(source) when is_binary(source), do: String.to_atom(source)
  defp normalize_source(source) when is_atom(source), do: source

  # Converts custom schema definitions (from relation macro) to a Drops.Relation.Schema struct
  defp convert_custom_definitions_to_schema(custom_schema_definitions, table_name) do
    # For now, create a temporary module and use EctoCompiler to convert it
    # This is a simplified version that still uses temporary modules but is more contained
    [{_table_name, schema_block}] = custom_schema_definitions

    # Generate a unique temporary module name
    temp_module_name =
      Module.concat([
        __MODULE__,
        TempCustomSchema,
        String.to_atom("Table_#{System.unique_integer([:positive])}")
      ])

    # Create the complete module AST
    module_ast =
      quote do
        defmodule unquote(temp_module_name) do
          use Ecto.Schema

          schema unquote(table_name) do
            unquote(schema_block)
          end
        end
      end

    # Compile and load the module
    Code.eval_quoted(module_ast)

    # Convert to Drops.Relation.Schema using EctoCompiler
    custom_drops_schema = Drops.Relation.Compilers.EctoCompiler.visit(temp_module_name, [])

    # Clean up temporary module
    :code.purge(temp_module_name)
    :code.delete(temp_module_name)

    custom_drops_schema
  end

  @doc """
  Updates an existing schema module using Igniter's zipper for sync mode.

  This function provides basic schema patching functionality for the gen_schemas
  mix task when in sync mode.

  ## Parameters

  - `zipper` - Sourceror.Zipper positioned at the module
  - `table_name` - The database table name
  - `schema` - The Drops.Relation.Schema struct

  ## Returns

  Updated zipper with schema modifications.
  """
  @spec update_schema_with_zipper(Sourceror.Zipper.t(), String.t(), Schema.t()) ::
          Sourceror.Zipper.t()
  def update_schema_with_zipper(zipper, table_name, schema) do
    # Get schema parts using Generator
    parts = generate_schema_parts(table_name, schema)

    # For now, use the Patcher module for sophisticated patching
    # This maintains the existing functionality while using Generator for data preparation
    alias Drops.Relation.Schema.Patcher

    # Convert parts to the format expected by Patcher
    compiled_parts = %{
      attributes: parts.attributes,
      field_definitions: parts.field_definitions
    }

    {:ok, updated_zipper} = Patcher.patch_schema_module(zipper, compiled_parts, table_name)
    updated_zipper
  end

  # Helper function to generate schema AST from field definitions with conditional timestamps
  defp generate_schema_ast_from_parts(table_name, field_definitions, schema, qualified \\ false) do
    # Check if the schema has timestamp fields
    has_inserted_at = Enum.any?(schema.fields, &(&1.name == :inserted_at))
    has_updated_at = Enum.any?(schema.fields, &(&1.name == :updated_at))

    schema_call =
      if qualified, do: {:., [], [{:__aliases__, [], [:Ecto, :Schema]}, :schema]}, else: :schema

    if has_inserted_at and has_updated_at do
      quote do
        unquote(schema_call)(unquote(table_name)) do
          (unquote_splicing(field_definitions))
          timestamps()
        end
      end
    else
      quote do
        unquote(schema_call)(unquote(table_name)) do
          (unquote_splicing(field_definitions))
        end
      end
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
