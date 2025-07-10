defmodule Drops.Relation.Schema.Generator do
  @moduledoc """
  Generates Ecto schema module content from database table introspection.

  This module handles the conversion of database table metadata into
  properly formatted Ecto schema definitions with field types, primary keys,
  and other schema attributes.
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey}

  require Logger

  @doc """
  Generates a complete Ecto schema module as a string.

  ## Parameters

  - `table_name` - The database table name
  - `module_name` - The full module name for the schema
  - `options` - Generation options including repo and other settings

  ## Returns

  A string containing the complete Ecto schema module definition.

  ## Examples

      iex> Generator.generate_schema_module("users", "MyApp.Relations.User", %{repo: "MyApp.Repo"})
      "defmodule MyApp.Relations.User do\\n  use Ecto.Schema\\n\\n  schema \\"users\\" do\\n..."
  """
  @spec generate_schema_module(String.t(), String.t() | atom(), map()) :: String.t()
  def generate_schema_module(table_name, module_name, options) do
    repo_name = options[:repo]

    # Ensure the repo module is loaded and started
    repo = ensure_repo_started(repo_name)

    # Use Database.table to get SQL Database Table struct, then compile to Relation Schema
    drops_relation_schema =
      case Drops.SQL.Database.table(table_name, repo) do
        {:ok, table} ->
          Drops.Relation.Schema.Compiler.visit(table, [])

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

  A string containing the module definition.
  """
  @spec generate_module_content(String.t(), String.t(), Schema.t()) :: String.t()
  def generate_module_content(_module_name, table_name, schema) do
    primary_key_attr = generate_primary_key_attribute(schema.primary_key)
    foreign_key_type_attr = generate_foreign_key_type_attribute(schema.fields)
    field_definitions = generate_field_definitions(schema.fields, schema.primary_key)

    """
    use Ecto.Schema

    #{primary_key_attr}#{foreign_key_type_attr}schema "#{table_name}" do
    #{field_definitions}  timestamps()
    end
    """
  end

  @doc """
  Generates the @primary_key attribute if needed.

  ## Parameters

  - `primary_key` - The PrimaryKey struct from the schema

  ## Returns

  A string containing the @primary_key attribute or empty string if default.
  """
  @spec generate_primary_key_attribute(PrimaryKey.t()) :: String.t()
  def generate_primary_key_attribute(%PrimaryKey{fields: fields}) do
    case fields do
      # Default case - single :id field
      [%Field{name: :id, type: :id}] ->
        ""

      # Ecto.UUID primary key - handled as regular field with primary_key: true
      [%Field{name: _name, type: Ecto.UUID}] ->
        ""

      # Single field with different name or type
      [%Field{name: name, type: type}] when name != :id or type != :id ->
        "  @primary_key {#{inspect(name)}, #{inspect(type)}, autogenerate: true}\n"

      # Composite primary key
      multiple_fields when length(multiple_fields) > 1 ->
        field_specs =
          Enum.map(multiple_fields, fn field ->
            "{#{inspect(field.name)}, #{inspect(field.type)}}"
          end)

        "  @primary_key [#{Enum.join(field_specs, ", ")}]\n"

      # No primary key
      [] ->
        "  @primary_key false\n"
    end
  end

  @doc """
  Generates the @foreign_key_type attribute if needed.

  ## Parameters

  - `fields` - List of Field structs from the schema

  ## Returns

  A string containing the @foreign_key_type attribute or empty string if not needed.
  """
  @spec generate_foreign_key_type_attribute([Field.t()]) :: String.t()
  def generate_foreign_key_type_attribute(fields) do
    # Check if there are any binary_id or Ecto.UUID fields that are explicitly marked as foreign keys
    # NO naming convention fallbacks - only use explicit metadata
    has_binary_id_fks =
      Enum.any?(fields, fn field ->
        # Only consider fields that are explicitly marked as foreign keys in metadata
        Map.get(field.meta, :is_foreign_key, false) and
          field.type in [:binary_id, Ecto.UUID]
      end)

    if has_binary_id_fks do
      "  @foreign_key_type :binary_id\n"
    else
      ""
    end
  end

  @doc """
  Generates field definitions for the schema block.

  ## Parameters

  - `fields` - List of Field structs

  ## Returns

  A string containing the field definitions, properly indented.
  """
  @spec generate_field_definitions([Field.t()]) :: String.t()
  def generate_field_definitions(fields) do
    fields
    |> Enum.reject(&is_timestamp_field?/1)
    |> Enum.map(&generate_field_definition/1)
    |> Enum.join("\n")
    |> case do
      "" -> ""
      content -> content <> "\n\n"
    end
  end

  @doc """
  Generates field definitions for the schema block, excluding primary key fields.

  ## Parameters

  - `fields` - List of Field structs
  - `primary_key` - PrimaryKey struct to identify which fields to exclude

  ## Returns

  A string containing the field definitions, properly indented.
  """
  @spec generate_field_definitions([Field.t()], PrimaryKey.t()) :: String.t()
  def generate_field_definitions(fields, primary_key) do
    primary_key_names = PrimaryKey.field_names(primary_key)

    fields
    |> Enum.reject(fn field ->
      # Don't exclude Ecto.UUID primary key fields - they need to be defined as regular fields
      field.name in primary_key_names and field.type != Ecto.UUID
    end)
    |> Enum.reject(&is_timestamp_field?/1)
    |> Enum.map(fn field ->
      # Add primary_key: true option for Ecto.UUID primary key fields
      if field.name in primary_key_names and field.type == Ecto.UUID do
        generate_uuid_primary_key_field_definition(field)
      else
        generate_field_definition(field)
      end
    end)
    |> Enum.join("\n")
    |> case do
      "" -> ""
      content -> content <> "\n\n"
    end
  end

  @doc """
  Generates a single field definition.

  ## Parameters

  - `field` - A Field struct

  ## Returns

  A string containing the field definition.
  """
  @spec generate_field_definition(Field.t()) :: String.t()
  def generate_field_definition(%Field{name: name, type: type, source: source}) do
    base_definition = "    field #{inspect(name)}, #{format_ecto_type(type)}"

    # Add source option if different from field name
    if source != name do
      "#{base_definition}, source: #{inspect(source)}"
    else
      base_definition
    end
  end

  @doc """
  Generates a field definition for Ecto.UUID primary key fields.

  ## Parameters

  - `field` - A Field struct with Ecto.UUID type

  ## Returns

  A string containing the field definition with primary_key: true option.
  """
  @spec generate_uuid_primary_key_field_definition(Field.t()) :: String.t()
  def generate_uuid_primary_key_field_definition(%Field{
        name: name,
        type: Ecto.UUID,
        source: source
      }) do
    base_definition =
      "    field #{inspect(name)}, #{format_ecto_type(Ecto.UUID)}, primary_key: true"

    # Add source option if different from field name
    if source != name do
      "#{base_definition}, source: #{inspect(source)}"
    else
      base_definition
    end
  end

  # Private helper functions

  defp is_timestamp_field?(%Field{name: name}) when name in [:inserted_at, :updated_at],
    do: true

  defp is_timestamp_field?(_), do: false

  defp format_ecto_type(type) when is_atom(type) do
    inspect(type)
  end

  defp format_ecto_type({:array, inner_type}) do
    "{:array, #{format_ecto_type(inner_type)}}"
  end

  defp format_ecto_type({:map, _}) do
    ":map"
  end

  defp format_ecto_type(type) do
    inspect(type)
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
      generate_module_content(module_name, table_name, schema)
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
