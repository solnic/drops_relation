defmodule Drops.Relation.AssociationsTest do
  use Test.RelationCase, async: false

  describe "defining associations" do
    relation(:user_groups) do
      schema("user_groups", infer: true) do
        belongs_to(:user, Test.Relations.Users)
        belongs_to(:group, Test.Relations.Groups)
      end
    end

    relation(:users) do
      schema("users", infer: true) do
        has_many(:user_groups, Test.Relations.UserGroups)
        has_many(:groups, through: [:user_groups, :group])
      end
    end

    relation(:groups) do
      schema("groups", infer: true) do
        has_many(:user_groups, Test.Relations.UserGroups)
        has_many(:users, through: [:user_groups, :user])
      end
    end

    test "returns relation view", %{users: users, groups: groups, user_groups: user_groups} do
      {:ok, user} = users.insert(%{name: "Jade"})
      {:ok, group} = groups.insert(%{name: "Admins"})

      user_groups.insert(%{user_id: user.id, group_id: group.id})

      user = users.preload(:groups) |> Enum.at(0)

      assert %{name: "Jade", groups: [%{name: "Admins"}]} = user
    end
  end
end
