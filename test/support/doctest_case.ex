defmodule Test.DoctestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      setup tags do
        if tags[:doctest] do
          adapter = String.to_atom(System.get_env("ADAPTER", "sqlite"))

          {:ok, _pid} = MyApp.Repo.start_link()
          Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)

          pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: true)

          {:ok, _} = Drops.Relation.Cache.warm_up(MyApp.Repo, ["users", "posts"])

          on_exit(fn ->
            Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
          end)
        end

        modules_before = Test.loaded_modules()

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
