defmodule Drops.Relation.ViewTest do
  use Drops.RelationCase, async: false

  describe "defining a relation view" do
    relation(:users) do
      schema("users", infer: true)

      view(:active) do
        schema([:id, :name, :active])

        derive do
          restrict(active: true)
        end
      end
    end

    test "returns relation view", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      [jane, jade] = users.active() |> Enum.to_list()

      assert jane.name == "Jane"
      assert jane.active
      assert :email not in Map.keys(jane)

      assert jade.name == "Jade"
      assert jade.active
      assert :email not in Map.keys(jade)
    end
  end

  describe "defining a relation view with custom struct name" do
    relation(:users) do
      schema("users", infer: true)

      view(:active) do
        schema([:id, :name, :active], struct: "ActiveUser")

        derive do
          restrict(active: true)
        end
      end
    end

    test "returns relation view", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      user = users.view(:active).first()

      assert user.__struct__ == Test.Relations.Users.Active.ActiveUser
    end
  end
end
