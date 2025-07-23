defmodule Drops.Relation.Query do
  @moduledoc """
  Provides query composition macros for building complex relation queries.

  This module contains macros for transforming query expressions and enabling
  composition of relation operations. It supports logical operations (AND/OR)
  and function call transformations within query contexts.

  ## Usage

  This module is primarily used internally by the query system, but can be
  used directly for advanced query composition scenarios.

      query(Users, [u], u.active() and u.by_role("admin"))

  ## Supported Operations

  - `and` - Logical AND composition
  - `or` - Logical OR composition
  - Function calls on relation bindings

  The macro transforms expressions to use the appropriate relation operations
  and maintains proper binding contexts for complex queries.
  """
  defmacro query(source, bindings, expression) do
    binding_vars = parse_bindings(bindings)
    transformed_expr = transform_expression(expression, binding_vars, source)

    quote do
      unquote(transformed_expr)
    end
  end

  defp parse_bindings([{var, _, context}]) when is_atom(var) and is_atom(context) do
    [{var, 0}]
  end

  defp parse_bindings(bindings) when is_list(bindings) do
    bindings
    |> Enum.with_index()
    |> Enum.map(fn
      {{var, _, context}, index} when is_atom(var) and is_atom(context) ->
        {var, index}
    end)
  end

  defp transform_expression({:or, _meta, [left, right]}, binding_vars, source) do
    left_transformed = transform_expression(left, binding_vars, source)
    right_transformed = transform_expression(right, binding_vars, source)

    quote do
      Drops.Relation.Operations.Or.new(
        unquote(left_transformed),
        unquote(right_transformed),
        unquote(source)
      )
    end
  end

  defp transform_expression({:and, _meta, [left, right]}, binding_vars, source) do
    left_transformed = transform_expression(left, binding_vars, source)
    right_transformed = transform_expression(right, binding_vars, source)

    quote do
      Drops.Relation.Operations.And.new(
        unquote(left_transformed),
        unquote(right_transformed),
        unquote(source)
      )
    end
  end

  defp transform_expression(
         {{:., dot_meta, [{var, var_meta, context}, function_name]}, call_meta, args},
         binding_vars,
         source
       )
       when is_atom(var) and is_atom(context) and is_atom(function_name) do
    case find_binding_var(var, binding_vars) do
      {:ok, _position} ->
        quote do
          unquote(source).unquote(function_name)(unquote_splicing(args))
        end

      :error ->
        {{:., dot_meta, [{var, var_meta, context}, function_name]}, call_meta, args}
    end
  end

  defp transform_expression(expr, _binding_vars, _source) do
    expr
  end

  defp find_binding_var(var, binding_vars) do
    case Enum.find(binding_vars, fn {binding_var, _pos} -> binding_var == var end) do
      {_var, position} -> {:ok, position}
      nil -> :error
    end
  end
end
