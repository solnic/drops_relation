defmodule Test.RelationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Test.DoctestCase

      alias Test.Repos.Sqlite
      alias Test.Repos.Postgres

      import Test.RelationCase
    end
  end

  setup tags do
    if tags[:test_type] != :doctest do
      adapter = Map.get(tags, :adapter, String.to_atom(System.get_env("ADAPTER", "sqlite")))

      setup_sandbox(tags, adapter)

      context =
        Enum.reduce(Map.get(tags, :relations, []), %{}, fn name, context ->
          Map.put(context, name, create_relation(name, adapter: adapter))
        end)

      on_exit(fn -> Test.cleanup_relation_modules(Map.values(context)) end)

      {:ok, Map.merge(context, %{adapter: adapter, repo: repo(adapter)})}
    else
      :ok
    end
  end

  defmacro relation(name, opts) do
    quote do
      setup context do
        relation_module = create_relation(unquote(name), unquote(Macro.escape(opts)))

        on_exit(fn -> Test.cleanup_relation_modules(relation_module) end)

        {:ok, Map.put(context, unquote(name), relation_module)}
      end
    end
  end

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

  def create_relation(name, opts) do
    adapter = Keyword.get(opts, :adapter, :sqlite)
    repo = repo(adapter)
    table_name = Atom.to_string(name)
    relation_name = Macro.camelize(table_name)

    module_name = Module.concat([Test, Relations, relation_name])

    block =
      Keyword.get(
        opts,
        :do,
        quote do
          schema(unquote(table_name), infer: true)
        end
      )

    Test.cleanup_relation_modules(module_name)

    {:ok, _} = Drops.Relation.Cache.warm_up(repo, [table_name])

    {:module, relation_module, _bytecode, _result} =
      Module.create(
        module_name,
        quote do
          use Drops.Relation, repo: unquote(repo)
          unquote(block)
        end,
        Macro.Env.location(__ENV__)
      )

    relation_module
  end

  def setup_sandbox(tags, adapter) do
    Test.Repos.start_owner!(adapter, shared: not tags[:async])
    on_exit(fn -> Test.Repos.stop_owner(adapter) end)
  end

  def repo(:sqlite), do: Test.Repos.Sqlite
  def repo(:postgres), do: Test.Repos.Postgres

  @doc """
  Helper for asserting column properties in SQL Database tables.

  ## Examples

      assert_column(table, :id, :integer, primary_key: true)
      assert_column(table, :email, :string, nullable: true, default: nil)
  """
  def assert_column(table, column_name, expected_type, opts \\ []) do
    column = table[column_name]

    assert column != nil, "Column #{column_name} not found in table"

    assert column.type == expected_type,
           "Expected column #{column_name} to have type #{inspect(expected_type)}, got #{inspect(column.type)}"

    Enum.each(opts, fn {key, expected_value} ->
      actual_value = Map.get(column.meta, key)

      assert actual_value == expected_value,
             "Expected column #{column_name} to have #{key}: #{inspect(expected_value)}, got #{inspect(actual_value)}"
    end)
  end

  @doc """
  Helper for asserting field properties in Relation schemas.

  ## Examples

      assert_field(schema, :id, :id, primary_key: true, type: :integer)
      assert_field(schema, :email, :string, nullable: true)
  """
  def assert_field(schema, field_name, expected_type, opts \\ []) do
    field = Drops.Relation.Schema.find_field(schema, field_name)

    assert field != nil, "Field #{field_name} not found in schema"

    assert field.type == expected_type,
           "Expected field #{field_name} to have type #{inspect(expected_type)}, got #{inspect(field.type)}"

    Enum.each(opts, fn {key, expected_value} ->
      actual_value = Map.get(field.meta, key, Map.get(field, key))

      assert actual_value == expected_value,
             "Expected field #{field_name} to have #{key}: #{inspect(expected_value)}, got #{inspect(actual_value)}"
    end)
  end
end
