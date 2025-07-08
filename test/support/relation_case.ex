defmodule Ecto.RelationCase do
  @moduledoc """
  Test case template for Ecto.Relation tests.

  This module provides a convenient way to test relation modules with automatic
  schema cache management and relation setup.

  ## Usage

      defmodule MyRelationTest do
        use Ecto.RelationCase, async: true

        describe "my relation tests" do
          @tag relations: [:users], adapter: :sqlite
          test "basic test", %{users: users} do
            # users relation is automatically available
          end

          # Or use the relation macro directly
          relation(:posts)

          test "posts test", %{posts: posts} do
            # posts relation is available
          end
        end
      end

  ## Multi-Adapter Testing

      defmodule MyMultiAdapterTest do
        use Ecto.RelationCase, async: true

        adapters([:sqlite, :postgres]) do
          @tag relations: [:users]
          test "works with both adapters", %{users: users} do
            # This test will run for both SQLite and PostgreSQL
          end
        end
      end

  ## Features

  - Automatic Ecto sandbox setup
  - Schema cache clearing for test isolation
  - Relation macro for defining test relations
  - Support for @tag relations: [...] and @describetag relations: [...]
  - Multi-adapter testing with adapters/2 macro
  - Automatic migration running for test tables
  - Adapter selection via @tag adapter: :sqlite/:postgres (defaults to :sqlite)
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Ecto.Relation.DoctestCase

      alias Ecto.Relation.Repos.Sqlite
      alias Ecto.Relation.Repos.Postgres

      import Ecto.RelationCase
    end
  end

  setup tags do
    # Determine adapter from tags, environment variable, or default to :sqlite
    adapter =
      tags[:adapter] ||
        (System.get_env("ADAPTER") &&
           String.downcase(System.get_env("ADAPTER")) |> String.to_atom()) ||
        :sqlite

    # Set up Ecto sandbox
    setup_sandbox(tags, adapter)

    # Handle relation tags
    {context, cleanup_modules} = handle_relation_tags(tags, adapter)

    # Set up cleanup for relation modules
    if cleanup_modules != [] do
      on_exit(fn ->
        Enum.each(cleanup_modules, fn module_name ->
          # Clean up protocol implementations first
          for protocol <- [Enumerable, Ecto.Queryable] do
            try do
              impl_module = Module.concat([protocol, module_name])

              if Code.ensure_loaded?(impl_module) do
                :code.purge(impl_module)
                :code.delete(impl_module)
              end
            rescue
              _ -> :ok
            end
          end

          # Then clean up the main module
          try do
            :code.purge(module_name)
            :code.delete(module_name)
          rescue
            _ -> :ok
          end
        end)
      end)
    end

    # Add adapter and repo to context
    context =
      Map.merge(context, %{
        adapter: adapter,
        repo: get_repo_for_adapter(adapter)
      })

    {:ok, context}
  end

  @doc """
  Defines a relation for testing.

  ## Examples

      relation(:users)
      relation(:posts) do
        # Custom relation configuration
      end
  """
  defmacro relation(name, opts) do
    relation_name = name |> Atom.to_string() |> Macro.camelize()

    quote do
      setup context do
        adapter = context[:adapter] || :sqlite
        table_name = Atom.to_string(unquote(name))

        # Define the relation module dynamically based on adapter
        relation_module_name =
          Module.concat([
            Test,
            Relations,
            "#{unquote(relation_name)}#{String.capitalize(Atom.to_string(adapter))}"
          ])

        repo_module =
          case adapter do
            :sqlite -> Ecto.Relation.Repos.Sqlite
            :postgres -> Ecto.Relation.Repos.Postgres
          end

        {:ok, _} = Ecto.Relation.SchemaCache.warm_up(repo_module, [table_name])

        block = Keyword.get(unquote(Macro.escape(opts)), :do, [])

        {:module, ^relation_module_name, _bytecode, _result} =
          Module.create(
            relation_module_name,
            quote do
              use Ecto.Relation,
                repo: unquote(repo_module),
                name: unquote(table_name),
                infer: true

              unquote(block)
            end,
            Macro.Env.location(__ENV__)
          )

        # Add relation to context
        relation_context = Map.put(context, unquote(name), relation_module_name)

        on_exit(fn ->
          # Clean up the module and its nested Struct module
          struct_module_name = Module.concat(relation_module_name, Struct)

          # Clean up protocol implementations first
          for protocol <- [Enumerable, Ecto.Queryable] do
            for module <- [relation_module_name, struct_module_name] do
              impl_module = Module.concat([protocol, module])

              :code.purge(impl_module)
              :code.delete(impl_module)
            end
          end

          # Then clean up the main modules
          :code.purge(struct_module_name)
          :code.delete(struct_module_name)

          :code.purge(relation_module_name)
          :code.delete(relation_module_name)
        end)

        {:ok, relation_context}
      end
    end
  end

  @doc """
  Runs tests for multiple adapters.

  ## Examples

      adapters([:sqlite, :postgres]) do
        @tag relations: [:users]
        test "works with both adapters", %{users: users} do
          # This test will run for both SQLite and PostgreSQL
        end
      end
  """
  defmacro adapters(adapter_list, do: block) do
    for adapter <- adapter_list do
      quote do
        describe "with #{unquote(adapter)} adapter" do
          setup do
            {:ok, adapter: unquote(adapter)}
          end

          unquote(block)
        end
      end
    end
  end

  @doc """
  Sets up the sandbox based on the test tags and adapter.
  """
  def setup_sandbox(tags, adapter) do
    Ecto.Relation.Repos.start_owner!(adapter, shared: not tags[:async])
    on_exit(fn -> Ecto.Relation.Repos.stop_owner(adapter) end)
  end

  @doc """
  Handles @tag relations: [...] and @describetag relations: [...] syntax.
  Returns {context, cleanup_modules} where cleanup_modules is a list of modules to clean up.
  """
  def handle_relation_tags(tags, adapter) do
    relations = tags[:relations] || []
    repo = get_repo_for_adapter(adapter)

    table_names = Enum.map(relations, &Atom.to_string/1)

    # Always force refresh in tests to ensure fresh schema inference
    {:ok, _} = Ecto.Relation.SchemaCache.refresh(repo, table_names)

    {context, cleanup_modules} =
      Enum.reduce(relations, {%{}, []}, fn relation_name, {context, cleanup_modules} ->
        relation_name_string = Atom.to_string(relation_name)
        relation_module_name = relation_name_string |> Macro.camelize()

        module_name =
          Module.concat([
            Test,
            Relations,
            "#{relation_module_name}#{String.capitalize(Atom.to_string(adapter))}"
          ])

        # Define the relation module dynamically
        # We need to use Module.create/3 for runtime module creation
        # Always purge and delete the module and its nested Struct module first to avoid redefinition warnings
        struct_module_name = Module.concat(module_name, Struct)

        # Clean up existing modules to avoid redefinition warnings
        for mod <- [struct_module_name, module_name] do
          :code.purge(mod)
          :code.delete(mod)
        end

        # Also clean up any protocol implementations that might exist
        # Protocol implementations are created with the pattern Protocol.ModuleName
        for protocol <- [Enumerable, Ecto.Queryable] do
          try do
            impl_module = Module.concat([protocol, module_name])

            if Code.ensure_loaded?(impl_module) do
              :code.purge(impl_module)
              :code.delete(impl_module)
            end
          rescue
            _ -> :ok
          end
        end

        # Also clean up protocol implementations for the Struct module
        for protocol <- [Enumerable, Ecto.Queryable] do
          try do
            impl_module = Module.concat([protocol, struct_module_name])

            if Code.ensure_loaded?(impl_module) do
              :code.purge(impl_module)
              :code.delete(impl_module)
            end
          rescue
            _ -> :ok
          end
        end

        {:module, ^module_name, _bytecode, _result} =
          Module.create(
            module_name,
            quote do
              use Ecto.Relation,
                repo: unquote(repo),
                name: unquote(relation_name_string),
                infer: true
            end,
            Macro.Env.location(__ENV__)
          )

        cleanup_modules = [struct_module_name, module_name | cleanup_modules]

        # Add to context
        context = Map.put(context, relation_name, module_name)
        {context, cleanup_modules}
      end)

    {context, cleanup_modules}
  end

  @doc """
  Gets the appropriate repo module for the given adapter.
  """
  def get_repo_for_adapter(:sqlite), do: Ecto.Relation.Repos.Sqlite
  def get_repo_for_adapter(:postgres), do: Ecto.Relation.Repos.Postgres
end
