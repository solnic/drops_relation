defmodule Drops.Relation.Compilers.EctoCompiler do
  @moduledoc """
  Compiler for converting compiled Ecto schema modules to Relation Schema structures.

  This module follows the same pattern as Drops.Relation.Compilers.SchemaCompiler but works with
  compiled Ecto schema modules and uses Ecto's reflection functions to extract schema
  information.

  The compiler is used to infer schema information from custom field definitions
  provided via the `schema` macro in relation modules.

  ## Usage

      # Convert a compiled Ecto schema module to a Relation Schema
      schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])

  ## Examples

      iex> schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])
      iex> schema.source
      "users"
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey}

  @doc """
  Main entry point for converting compiled Ecto schema module to Relation Schema.

  ## Parameters

  - `schema_module` - A compiled Ecto schema module
  - `opts` - Optional compilation options

  ## Returns

  A Drops.Relation.Schema.t() struct.

  ## Examples

      iex> schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, [])
      iex> %Drops.Relation.Schema{} = schema
  """
  def visit(schema_module, _opts) when is_atom(schema_module) do
    # Ensure the module is loaded and is an Ecto schema
    unless Code.ensure_loaded?(schema_module) and
             function_exported?(schema_module, :__schema__, 1) do
      raise ArgumentError, "Expected compiled Ecto schema module, got: #{inspect(schema_module)}"
    end

    # Extract information using Ecto's reflection functions
    source = schema_module.__schema__(:source)
    fields = extract_fields_from_schema(schema_module)
    primary_key = extract_primary_key_from_schema(schema_module)

    # For now, we don't handle foreign keys and indices from Ecto schemas
    # These would typically be inferred from associations which we're ignoring for now
    foreign_keys = []
    indices = []

    Schema.new(source, primary_key, foreign_keys, fields, indices)
  end

  def visit(other, _opts) do
    raise ArgumentError, "Expected compiled Ecto schema module, got: #{inspect(other)}"
  end

  # Extract field information from compiled Ecto schema module
  defp extract_fields_from_schema(schema_module) do
    field_names = schema_module.__schema__(:fields)

    Enum.map(field_names, fn field_name ->
      field_type = schema_module.__schema__(:type, field_name)
      field_source = schema_module.__schema__(:field_source, field_name)

      meta = %{
        type: field_type,
        source: field_source,
        # Ecto doesn't expose this information easily
        nullable: nil,
        # Ecto doesn't expose this information easily
        default: nil,
        check_constraints: [],
        primary_key: field_name in schema_module.__schema__(:primary_key),
        # We'll handle this separately if needed
        foreign_key: false
      }

      Field.new(field_name, field_type, meta)
    end)
  end

  # Extract primary key information from compiled Ecto schema module
  defp extract_primary_key_from_schema(schema_module) do
    primary_key_fields = schema_module.__schema__(:primary_key)

    # Convert field names to Field structs for the primary key
    pk_field_structs =
      Enum.map(primary_key_fields, fn field_name ->
        field_type = schema_module.__schema__(:type, field_name)
        field_source = schema_module.__schema__(:field_source, field_name)

        meta = %{
          type: field_type,
          source: field_source,
          # Primary key fields are typically not nullable
          nullable: false,
          default: nil,
          check_constraints: [],
          primary_key: true,
          foreign_key: false
        }

        Field.new(field_name, field_type, meta)
      end)

    PrimaryKey.new(pk_field_structs)
  end
end
