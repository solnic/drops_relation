defmodule Drops.Relation.Generator do
  @moduledoc false

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.Patcher
  alias Drops.Relation.Compilers.CodeCompiler
  alias Drops.Relation.Compilers.EctoCompiler

  require Logger

  @spec generate_module(String.t() | atom(), Schema.t()) :: Macro.t()
  def generate_module(module_name, schema) when is_binary(module_name) do
    generate_module(Module.concat(String.split(module_name, ".")), schema)
  end

  def generate_module(module_name, schema) do
    schema_ast = generate_module_content(schema)

    quote do
      defmodule unquote(module_name) do
        unquote(schema_ast)
      end
    end
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
  @spec generate_module_content(Schema.t(), [Macro.t()]) :: Macro.t()
  def generate_module_content(schema, custom_block \\ []) do
    table_name = if is_atom(schema.source), do: Atom.to_string(schema.source), else: schema.source
    compiled_parts = CodeCompiler.visit(schema)

    filtered_custom_block = filter_fields(custom_block, schema)

    attributes =
      Enum.reject([compiled_parts.primary_key, compiled_parts.foreign_key_type], &(&1 == []))

    fields = compiled_parts.fields

    timestamps =
      if not is_nil(schema[:inserted_at]) and not is_nil(schema[:updated_at]) do
        quote do
          timestamps()
        end
      else
        []
      end

    quote do
      use Ecto.Schema
      unquote_splicing(attributes)

      schema unquote(table_name) do
        unquote_splicing(fields)

        unquote(timestamps)

        unquote(filtered_custom_block)
      end
    end
  end

  # Converts custom schema block to a Drops.Relation.Schema struct
  def schema_from_block(table_name, schema_block) do
    module =
      Module.concat([
        __MODULE__,
        TempCustomSchema,
        String.to_atom("Table_#{table_name}_#{System.unique_integer([:positive])}")
      ])

    module_ast =
      quote do
        defmodule unquote(module) do
          use Ecto.Schema

          schema unquote(table_name) do
            unquote(schema_block)
          end
        end
      end

    Code.eval_quoted(module_ast)

    schema = EctoCompiler.visit(module, [])

    :code.purge(module)
    :code.delete(module)

    schema
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
    compiled_parts = CodeCompiler.visit(schema)

    {:ok, updated_zipper} = Patcher.patch_schema_module(zipper, compiled_parts, table_name)

    updated_zipper
  end

  @spec filter_fields(Macro.t(), Schema.t()) :: Macro.t()
  defp filter_fields(custom_block, schema) do
    existing_field_names = MapSet.new(schema.fields, & &1.name)
    filter_ast_fields(custom_block, existing_field_names)
  end

  @spec filter_ast_fields(Macro.t(), MapSet.t()) :: Macro.t()
  defp filter_ast_fields({:__block__, meta, expressions}, existing_fields) do
    {:__block__, meta, Enum.map(expressions, &filter_ast_fields(&1, existing_fields))}
  end

  defp filter_ast_fields({:field, _meta, [field_name | _rest]} = field_ast, existing_fields) do
    if MapSet.member?(existing_fields, field_name), do: nil, else: field_ast
  end

  defp filter_ast_fields(ast, _existing_fields), do: ast
end
