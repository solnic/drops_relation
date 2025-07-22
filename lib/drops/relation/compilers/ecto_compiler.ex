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
      schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, %{})

  ## Examples

      iex> schema = Drops.Relation.Compilers.EctoCompiler.visit(MyApp.UserSchema, %{})
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
    source = String.to_atom(schema_module.__schema__(:source))

    associations =
      Enum.map(schema_module.__schema__(:associations), fn name ->
        schema_module.__schema__(:association, name)
      end)

    opts = %{
      associations: associations,
      pk: schema_module.__schema__(:primary_key),
      defaults: Map.from_struct(struct(schema_module))
    }

    fields =
      Enum.map(schema_module.__schema__(:load), fn {name, type} ->
        {:field, {name, type, schema_module.__schema__(:field_source, name)}}
      end)
      |> Enum.map(&visit(&1, opts))

    primary_key = PrimaryKey.new(Enum.filter(fields, & &1.meta[:primary_key]))

    Schema.new(source, fields, primary_key: primary_key)
  end

  def visit({:field, {name, type, source}}, %{
        associations: associations,
        pk: pk,
        defaults: defaults
      }) do
    assoc =
      Enum.find(associations, fn assoc ->
        assoc.owner_key == name and name not in pk
      end)

    foreign_key = if is_nil(assoc), do: false, else: true

    meta = %{
      source: source,
      default: defaults[name],
      nullable: nil,
      check_constraints: [],
      primary_key: name in pk,
      foreign_key: foreign_key,
      association: not is_nil(assoc)
    }

    Field.new(name, type, meta)
  end
end
