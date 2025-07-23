defmodule Drops.Relation.Plugins.AutoRestrict.SchemaCompiler do
  @moduledoc false

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
        __MODULE__.restrict(__MODULE__.new(), [{unquote(name), value}])
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
        __MODULE__.restrict(__MODULE__.new(), clauses)
      end

      def unquote(get_function_name)(queryable, unquote_splicing(param_names)) do
        clauses = unquote(clauses_ast)
        __MODULE__.restrict(queryable, clauses)
      end
    end
  end
end
