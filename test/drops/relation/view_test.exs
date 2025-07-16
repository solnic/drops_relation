defmodule Drops.Relation.ViewTest do
  use Drops.RelationCase, async: false

  describe "defining a relation view" do
    relation(:users) do
      schema("users", infer: true)

      view(:active) do
        schema([:id, :name, :active])

        relation do
          restrict(active: true)
        end
      end
    end

    test "returns relation view", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      assert [%{name: "Jane"}, %{name: "Jade"}] = users.active() |> Enum.to_list()
    end
  end
end
