defmodule Drops.Relation.Plugins.Ecto.Query do
  @moduledoc """
  Plugin for defining custom Ecto queries within relation modules.

  This plugin provides the `defquery` macro that allows defining custom query functions
  that return relation structs with the queryable set to the result of the query block.

  ## Architecture

  For each relation module that defines queries, this plugin creates a dedicated
  QueryBuilder module (e.g., `MyRelation.QueryBuilder`) that contains the actual
  query functions with `Ecto.Query` imported once at the module level. The relation
  module then delegates to these QueryBuilder functions.

  This approach avoids importing `Ecto.Query` in each generated function and provides
  a clean separation of concerns.

  ## Usage

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)

        defquery active() do
          from(u in relation(), where: u.active == true)
        end

        defquery by_role(role) when is_binary(role) do
          from(u in relation(), where: u.role == ^role)
        end

        defquery recent(days \\ 7) do
          cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)
          from(u in relation(), where: u.inserted_at >= ^cutoff)
        end
      end

      # This creates:
      # - MyApp.Users.active() -> delegates to MyApp.Users.QueryBuilder.active()
      # - MyApp.Users.QueryBuilder module with Ecto.Query imported
      # - relation() function available in query blocks

      # Usage examples:
      active_users = MyApp.Users.active() |> MyApp.Users.all()
      admin_users = MyApp.Users.by_role("admin") |> MyApp.Users.all()
      recent_users = MyApp.Users.recent(30) |> MyApp.Users.all()

  The `relation()` function within the query block returns the relation module, allowing
  you to reference the current relation in your Ecto queries.
  """

  use Drops.Relation.Plugin, imports: [defquery: 2]

  defmodule Macros.Defquery do
    @moduledoc false

    use Drops.Relation.Plugin.MacroStruct,
      key: :queries,
      accumulate: true,
      struct: [:name, :args, :guards, :block]

    def new(name, args, guards, block) when is_atom(name) and is_list(args) and is_tuple(block) do
      %Macros.Defquery{name: name, args: args, guards: guards, block: block}
    end

    def new(name, args, block) when is_atom(name) and is_list(args) and is_tuple(block) do
      %Macros.Defquery{name: name, args: args, guards: nil, block: block}
    end
  end

  defmacro defquery(call, do: block) do
    {name, args, guards} = parse_function_call_with_guards(call)

    arg_names =
      Enum.map(args, fn
        {var_name, _, _} when is_atom(var_name) -> var_name
        var_name when is_atom(var_name) -> var_name
      end)

    quote do
      @context update_context(__MODULE__, Macros.Defquery, [
                 unquote(name),
                 unquote(arg_names),
                 unquote(Macro.escape(guards)),
                 unquote(Macro.escape(block))
               ])
    end
  end

  def on(:before_compile, relation, _) do
    queries = context(relation, :queries)

    if queries do
      grouped_queries = Enum.group_by(queries, & &1.name)

      delegation_functions =
        Enum.flat_map(grouped_queries, fn {_name, queries_group} ->
          original_functions =
            Enum.map(queries_group, &generate_original_delegation_function(relation, &1))

          composable_functions =
            Enum.map(queries_group, &generate_composable_delegation_function(relation, &1))

          original_functions ++ composable_functions
        end)

      quote do
        (unquote_splicing(delegation_functions))
      end
    else
      quote do: nil
    end
  end

  def on(:after_compile, relation, _) do
    queries = context(relation, :queries)

    if queries do
      quote location: :keep do
        unquote(__MODULE__).create_query_builder_module(
          unquote(relation),
          unquote(Macro.escape(queries))
        )
      end
    else
      quote do: nil
    end
  end

  def create_query_builder_module(relation, queries) do
    query_builder_module = query_builder_module_name(relation)
    grouped_queries = Enum.group_by(queries, & &1.name)

    query_functions =
      Enum.flat_map(grouped_queries, fn {_name, queries_group} ->
        original_functions = Enum.map(queries_group, &generate_query_function(relation, &1))

        composable_functions =
          Enum.map(queries_group, &generate_composable_query_function(relation, &1))

        original_functions ++ composable_functions
      end)

    module_code =
      quote do
        import Ecto.Query

        def relation(), do: unquote(relation)

        (unquote_splicing(query_functions))
      end

    Module.create(
      query_builder_module,
      module_code,
      Macro.Env.location(__ENV__)
    )
  end

  defp parse_function_call_with_guards({:when, _meta, [call, guards]}) do
    {name, args} = Macro.decompose_call(call)
    {name, args, guards}
  end

  defp parse_function_call_with_guards(call) do
    {name, args} = Macro.decompose_call(call)
    {name, args, nil}
  end

  defp generate_original_delegation_function(relation, %{name: name, args: args, guards: guards}) do
    query_builder_module = query_builder_module_name(relation)
    arg_names = args
    param_vars = Enum.map(arg_names, &Macro.var(&1, nil))

    function_head =
      if guards do
        {:when, [], [{name, [], param_vars}, guards]}
      else
        {name, [], param_vars}
      end

    quote do
      def unquote(function_head) do
        queryable = unquote(query_builder_module).unquote(name)(unquote_splicing(param_vars))
        new(queryable, [])
      end
    end
  end

  defp generate_composable_delegation_function(relation, %{name: name, args: args, guards: guards}) do
    query_builder_module = query_builder_module_name(relation)
    arg_names = args
    param_vars = Enum.map(arg_names, &Macro.var(&1, nil))
    queryable_var = Macro.var(:queryable, nil)

    function_head =
      if guards do
        {:when, [], [{name, [], [queryable_var | param_vars]}, guards]}
      else
        {name, [], [queryable_var | param_vars]}
      end

    quote do
      def unquote(function_head) do
        query =
          unquote(query_builder_module).unquote(name)(
            unquote(queryable_var),
            unquote_splicing(param_vars)
          )

        new(query, [])
      end
    end
  end

  defp generate_query_function(_relation, %{name: name, args: args, guards: guards, block: block}) do
    arg_names = args
    param_vars = Enum.map(arg_names, &Macro.var(&1, nil))

    updated_block = replace_variables_in_block(block, arg_names)

    function_head =
      if guards do
        {:when, [], [{name, [], param_vars}, guards]}
      else
        {name, [], param_vars}
      end

    quote do
      def unquote(function_head) do
        unquote(updated_block)
      end
    end
  end

  defp generate_composable_query_function(_relation, %{
         name: name,
         args: args,
         guards: guards,
         block: block
       }) do
    arg_names = args
    queryable_var = Macro.var(:queryable, nil)
    param_vars = Enum.map(arg_names, &Macro.var(&1, nil))

    updated_block =
      block
      |> replace_variables_in_block(arg_names)
      |> replace_relation_calls_with_queryable()

    function_head =
      if guards do
        {:when, [], [{name, [], [queryable_var | param_vars]}, guards]}
      else
        {name, [], [queryable_var | param_vars]}
      end

    quote do
      def unquote(function_head) do
        unquote(updated_block)
      end
    end
  end

  defp replace_variables_in_block(block, arg_names) do
    Macro.postwalk(block, fn
      {var_name, _meta, _context} = var_ast when is_atom(var_name) ->
        if var_name in arg_names do
          Macro.var(var_name, nil)
        else
          var_ast
        end

      other ->
        other
    end)
  end

  defp replace_relation_calls_with_queryable(block) do
    Macro.postwalk(block, fn
      {:relation, _meta, []} ->
        Macro.var(:queryable, nil)

      other ->
        other
    end)
  end

  defp query_builder_module_name(relation) do
    Module.concat([relation, QueryBuilder])
  end
end
