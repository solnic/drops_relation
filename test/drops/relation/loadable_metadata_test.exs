defmodule Drops.Relation.LoadableMetadataTest do
  use Drops.RelationCase, async: false

  alias Drops.Relation.Loaded

  describe "Loadable protocol with metadata" do
    @tag relations: [:users]
    test "load function returns Loaded struct with metadata", %{users: users} do
      # Insert test data
      insert_test_users(users, 10)

      # Create a basic relation and load it
      relation = users.restrict(active: true)
      loaded = users.load(relation)

      assert %Loaded{} = loaded
      assert length(loaded.data) == 10
      assert is_map(loaded.meta)
    end

    @tag relations: [:users]
    test "pagination metadata is properly included", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Test the desired usage pattern: Users.per_page(10) |> Users.page(1) |> Users.load()
      loaded = users.per_page(10) |> users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 3
      assert loaded.meta.pagination.has_next == true
      assert loaded.meta.pagination.has_prev == false
      assert loaded.meta.pagination.offset == 0
      assert length(loaded.data) == 10
    end

    @tag relations: [:users]
    test "metadata is preserved when chaining operations", %{users: users} do
      # Insert test data
      insert_test_users(users, 15)

      # Chain operations: restrict -> per_page -> page
      loaded = users
               |> users.restrict(active: true)
               |> users.per_page(5)
               |> users.page(2)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 2
      assert loaded.meta.pagination.per_page == 5
      assert loaded.meta.pagination.total_count == 15
      assert loaded.meta.pagination.total_pages == 3
      assert loaded.meta.pagination.has_next == true
      assert loaded.meta.pagination.has_prev == true
      assert loaded.meta.pagination.offset == 5
      assert length(loaded.data) == 5
    end

    @tag relations: [:users]
    test "load function works without pagination metadata", %{users: users} do
      # Insert test data
      insert_test_users(users, 5)

      # Load without pagination
      relation = users.restrict(active: true)
      loaded = users.load(relation)

      assert %Loaded{} = loaded
      assert length(loaded.data) == 5
      assert loaded.meta == %{}
    end
  end

  describe "Enumerable protocol with metadata" do
    @tag relations: [:users]
    test "Enumerable works on relation structs", %{users: users} do
      # Insert test data
      insert_test_users(users, 5)

      # Create a relation and use Enum functions
      relation = users.restrict(active: true)
      
      # Test Enum.count
      assert Enum.count(relation) == 5
      
      # Test Enum.map
      names = Enum.map(relation, & &1.name)
      assert length(names) == 5
      assert Enum.all?(names, &is_binary/1)
    end

    @tag relations: [:users]
    test "Enumerable works on paginated results", %{users: users} do
      # Insert test data
      insert_test_users(users, 10)

      # Create paginated result
      loaded = users.per_page(5) |> users.page(1)
      
      # Test Enum functions on Loaded struct
      assert Enum.count(loaded) == 5
      
      names = Enum.map(loaded, & &1.name)
      assert length(names) == 5
      
      user_list = Enum.to_list(loaded)
      assert length(user_list) == 5
      assert user_list == loaded.data
    end
  end

  # Helper function to insert test users
  defp insert_test_users(users, count) do
    for i <- 1..count do
      {:ok, _} = users.insert(%{
        name: "User #{i}",
        email: "user#{i}@example.com",
        active: true
      })
    end
  end
end
