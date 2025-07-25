defmodule Drops.Relation.Plugins.Queryable.Operations.OrderTest do
  use Test.RelationCase, async: false

  describe "order operations with various specifications" do
    @tag relations: [:users]
    test "order by single atom field", %{users: users} do
      users.insert(%{name: "Charlie", email: "charlie@example.com"})
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      relation = users.order(:name)
      ordered_users = Enum.to_list(relation)

      names = Enum.map(ordered_users, & &1.name)
      assert names == ["Alice", "Bob", "Charlie"]
    end

    @tag relations: [:users]
    test "order by list of fields", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      relation = users.order([:name, :email])
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 0).email == "alice1@example.com"
      assert Enum.at(ordered_users, 1).name == "Alice"
      assert Enum.at(ordered_users, 1).email == "alice2@example.com"
      assert Enum.at(ordered_users, 2).name == "Bob"
    end

    @tag relations: [:users]
    test "order with direction tuple", %{users: users} do
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})
      users.insert(%{name: "Charlie", email: "charlie@example.com"})

      # Test descending order
      relation = users.order({:desc, :name})
      ordered_users = Enum.to_list(relation)

      names = Enum.map(ordered_users, & &1.name)
      assert names == ["Charlie", "Bob", "Alice"]
    end

    @tag relations: [:users]
    test "order with keyword list directions", %{users: users} do
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})
      users.insert(%{name: "Charlie", email: "charlie@example.com"})

      # Test with keyword list
      relation = users.order(desc: :name)
      ordered_users = Enum.to_list(relation)

      names = Enum.map(ordered_users, & &1.name)
      assert names == ["Charlie", "Bob", "Alice"]
    end

    @tag relations: [:users]
    test "order with mixed directions", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Test mixed directions: name asc, email desc
      relation = users.order(asc: :name, desc: :email)
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 0).email == "alice2@example.com"
      assert Enum.at(ordered_users, 1).name == "Alice"
      assert Enum.at(ordered_users, 1).email == "alice1@example.com"
      assert Enum.at(ordered_users, 2).name == "Bob"
    end
  end

  describe "order error handling" do
    @tag relations: [:users]
    test "order by non-existent field raises error", %{users: users} do
      alias Drops.Relation.Plugins.Queryable.InvalidQueryError

      assert_raise InvalidQueryError, ~r/Field 'nonexistent' not found in schema/, fn ->
        users.order(:nonexistent) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "order with invalid direction raises error", %{users: users} do
      alias Drops.Relation.Plugins.Queryable.InvalidQueryError

      assert_raise InvalidQueryError, ~r/invalid order specification/, fn ->
        users.order([{:invalid_direction, :name}]) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "order with invalid specification raises error", %{users: users} do
      alias Drops.Relation.Plugins.Queryable.InvalidQueryError

      assert_raise InvalidQueryError, ~r/invalid order specification/, fn ->
        users.order(%{invalid: :spec}) |> Enum.to_list()
      end
    end
  end

  describe "order composition" do
    @tag relations: [:users]
    test "multiple order calls accumulate", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Chain multiple order calls
      relation =
        users
        |> users.order(:name)
        |> users.order(:email)

      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      # Should be ordered by name first, then email
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 0).email == "alice1@example.com"
      assert Enum.at(ordered_users, 1).name == "Alice"
      assert Enum.at(ordered_users, 1).email == "alice2@example.com"
      assert Enum.at(ordered_users, 2).name == "Bob"
    end

    @tag relations: [:users]
    test "order composes with restrict", %{users: users} do
      users.insert(%{name: "Alice", email: "alice@example.com", active: true})
      users.insert(%{name: "Bob", email: "bob@example.com", active: false})
      users.insert(%{name: "Charlie", email: "charlie@example.com", active: true})

      relation =
        users
        |> users.restrict(active: true)
        |> users.order(:name)

      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 2
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 1).name == "Charlie"
      assert Enum.all?(ordered_users, & &1.active)
    end

    @tag relations: [:users]
    test "order sets operation metadata", %{users: users} do
      relation = users.order(:name)
      assert relation.operations == [:order]

      # Test chaining with restrict
      chained_relation = users.restrict(active: true) |> users.order(:name)
      assert chained_relation.operations == [:restrict, :order]
    end
  end

  describe "order with different data types" do
    @tag relations: [:users]
    test "order by integer field", %{users: users} do
      users.insert(%{name: "User 1", email: "user1@example.com", age: 30})
      users.insert(%{name: "User 2", email: "user2@example.com", age: 25})
      users.insert(%{name: "User 3", email: "user3@example.com", age: 35})

      relation = users.order(:age)
      ordered_users = Enum.to_list(relation)

      ages = Enum.map(ordered_users, & &1.age)
      assert ages == [25, 30, 35]
    end

    @tag relations: [:users]
    test "order by boolean field", %{users: users} do
      users.insert(%{name: "Active User", email: "active@example.com", active: true})
      users.insert(%{name: "Inactive User", email: "inactive@example.com", active: false})

      # Order by boolean (false comes before true in ascending order)
      relation = users.order(:active)
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 2
      assert Enum.at(ordered_users, 0).active == false
      assert Enum.at(ordered_users, 1).active == true
    end
  end
end
