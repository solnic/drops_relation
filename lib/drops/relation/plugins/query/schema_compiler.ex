defmodule Drops.Relation.Plugins.Query.SchemaCompiler do
  @moduledoc """
  Compiler for generating get_by_* finder functions from Drops.Relation.Schema structures.

  This module follows the visitor pattern similar to CodeCompiler but focuses specifically
  on generating quoted expressions for index-based finder functions. It supports both
  single field and composite index finders.

  ## Usage

      # Generate finder functions from a schema
      schema = %Drops.Relation.Schema{...}
      finder_asts = Drops.Relation.Query.SchemaCompiler.visit(schema, %{repo: MyRepo})
  """

  alias Drops.Relation.Schema

  @doc """
  Main entry point for generating finder functions from a Relation Schema.

  ## Parameters

  - `schema` - A Drops.Relation.Schema struct
  - `opts` - Compilation options including `:repo`

  ## Returns

  A list of quoted expressions representing get_by_* and find_by_* functions.

  ## Examples

      iex> schema = %Drops.Relation.Schema{indices: ...}
      iex> asts = Drops.Relation.Query.SchemaCompiler.visit(schema, %{repo: MyRepo})
      iex> is_list(asts)
      true
  """
  def visit(%Schema{indices: indices}, opts) do
    Enum.map(indices, &visit(&1, opts))
  end

  def visit(%{fields: [%{name: name}], composite: false}, _opts) do
    function_name = String.to_atom("get_by_#{name}")

    quote do
      def unquote(function_name)(value) do
        __MODULE__.restrict(__MODULE__, [{unquote(name), value}])
      end

      def unquote(function_name)(queryable, value) do
        __MODULE__.restrict(queryable, [{unquote(name), value}])
      end
    end
  end

  def visit(%{fields: fields, composite: true}, _opts) do
    field_names = Enum.map(fields, & &1.name)
    function_suffix = Enum.join(field_names, "_and_")
    get_function_name = String.to_atom("get_by_#{function_suffix}")

    param_names = Enum.map(field_names, &Macro.var(&1, nil))

    clauses_ast =
      Enum.map(field_names, fn field_name ->
        {:{}, [], [field_name, Macro.var(field_name, nil)]}
      end)

    quote do
      def unquote(get_function_name)(unquote_splicing(param_names)) do
        clauses = unquote(clauses_ast)
        __MODULE__.restrict(__MODULE__, clauses)
      end

      def unquote(get_function_name)(queryable, unquote_splicing(param_names)) do
        clauses = unquote(clauses_ast)
        __MODULE__.restrict(queryable, clauses)
      end
    end
  end
end
