defmodule Test.DoctestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)

      setup tags do
        if tags[:test_type] == :doctest do
          :ok = Test.Repos.start_owner!(MyApp.Repo, shared: not tags[:async])

          {:ok, _} = Drops.Relation.Cache.warm_up(MyApp.Repo, ["users", "posts"])

          modules_before = Test.loaded_modules()

          fixtures = tags[:fixtures] || []

          Test.Fixtures.load(fixtures)

          on_exit(fn ->
            :ok = Test.Repos.stop_owner(MyApp.Repo)

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
        end

        :ok
      end
    end
  end
end
