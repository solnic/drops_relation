defmodule Test.DoctestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      setup tags do
        modules_before = Test.loaded_modules()

        if tags[:test_type] == :doctest do
          {:ok, _pid} = MyApp.Repo.start_link()

          Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)

          pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: true)

          {:ok, _} = Drops.Relation.Cache.warm_up(MyApp.Repo, ["users", "posts"])

          fixtures = tags[:fixtures] || []

          Enum.each(fixtures, fn name ->
            table_name = Atom.to_string(name)
            module_name = Module.concat([MyApp, Drops.Inflector.camelize(name)])

            {:module, module, _, _} =
              Module.create(
                module_name,
                quote do
                  use Drops.Relation, otp_app: :my_app
                  schema(unquote(table_name), infer: true)
                end,
                Macro.Env.location(__ENV__)
              )
          end)

          Test.Fixtures.load(fixtures)

          on_exit(fn ->
            Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
          end)
        end

        on_exit(fn ->
          new_modules = MapSet.difference(Test.loaded_modules(), modules_before)
          test_module_prefix = to_string(__MODULE__)

          Enum.each(new_modules, fn module ->
            module_string = to_string(module)

            if String.starts_with?(module_string, test_module_prefix) do
              Test.clear_module(module_string)
            end

            if function_exported?(module, :schema, 0) do
              Test.cleanup_relation_modules(module)
            end
          end)
        end)

        :ok
      end
    end
  end
end
