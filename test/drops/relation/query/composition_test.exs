defmodule Drops.Relations.CompositionTest do
  use Test.RelationCase, async: false

  describe "restrict/1" do
    @tag relations: [:users]
    test "composing", %{users: users} do
      users.insert(%{name: "Jane", email: "jane@doe.org"})
      users.insert(%{name: "Jane", email: "jane.doe@earth.org"})

      relation =
        users
        |> users.restrict(name: "Jane")
        |> users.restrict(email: "jane@doe.org")

      # Test both Enum.at and List.first (which should work via Enumerable)
      assert jane = Enum.at(relation, 0)

      # Also test that we can convert to list and use List.first
      relation_list = Enum.to_list(relation)
      assert jane_from_list = List.first(relation_list)
      assert jane_from_list.name == jane.name

      assert jane.name == "Jane"
      assert jane.email == "jane@doe.org"
    end
  end

  describe "get_by_email/1 - auto-generated composable finders" do
    @tag relations: [:users]
    test "composing", %{users: users} do
      users.insert(%{name: "Jane", email: "jane@doe.org"})
      users.insert(%{name: "Jane", email: "jane.doe@earth.org"})

      relation =
        users.get_by_email("jane.doe@earth.org")
        |> users.restrict(name: "Jane")

      # Test both Enum.at and List.first (which should work via Enumerable)
      assert jane = Enum.at(relation, 0)

      # Also test that we can convert to list and use List.first
      relation_list = Enum.to_list(relation)
      assert jane_from_list = List.first(relation_list)
      assert jane_from_list.name == jane.name

      assert jane.name == "Jane"
      assert jane.email == "jane.doe@earth.org"
    end
  end

  @tag relations: [:users]
  test "enumerable protocol works with various functions", %{users: users} do
    users.insert(%{name: "Alice", email: "alice@example.com"})
    users.insert(%{name: "Bob", email: "bob@example.com"})
    users.insert(%{name: "Charlie", email: "charlie@example.com"})

    relation = users |> users.restrict(name: "Alice")

    # Test Enum.count
    assert Enum.count(relation) == 1

    # Test Enum.map
    emails = Enum.map(relation, & &1.email)
    assert emails == ["alice@example.com"]

    # Test Enum.filter (should work on the materialized list)
    filtered = Enum.filter(relation, fn user -> String.contains?(user.email, "alice") end)
    assert length(filtered) == 1

    # Test Enum.any?
    assert Enum.any?(relation, fn user -> user.name == "Alice" end)
    refute Enum.any?(relation, fn user -> user.name == "Bob" end)
  end

  @tag relations: [:users]
  test "enumerable protocol works with empty results", %{users: users} do
    users.insert(%{name: "Alice", email: "alice@example.com"})

    # Create a relation that should return no results
    relation = users |> users.restrict(name: "NonExistent")

    # Test with empty results
    assert Enum.count(relation) == 0
    assert Enum.to_list(relation) == []
    assert Enum.at(relation, 0) == nil
    refute Enum.any?(relation, fn _ -> true end)
  end

  @tag relations: [:users]
  test "ecto queryable protocol works", %{users: users} do
    users.insert(%{name: "Alice", email: "alice@example.com"})
    users.insert(%{name: "Bob", email: "bob@example.com"})

    # Test that relation structs can be used in Ecto queries
    relation = users |> users.restrict(name: "Alice")

    # Convert to Ecto.Query and verify it works
    query = Ecto.Queryable.to_query(relation)
    assert %Ecto.Query{} = query

    # Test that the relation module itself can be used as queryable
    module_query = Ecto.Queryable.to_query(users)
    assert %Ecto.Query{} = module_query
  end
end
