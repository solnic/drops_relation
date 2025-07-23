defmodule Drops.Relation.Plugins.PaginationTest do
  use Drops.RelationCase, async: false

  alias Drops.Relation.Loaded

  describe "basic pagination" do
    @tag relations: [:users]
    test "page/1 returns first page with default per_page", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Test first page
      loaded = users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      # default per_page
      assert loaded.meta.pagination.per_page == 20
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 2
      assert loaded.meta.pagination.has_next == true
      assert loaded.meta.pagination.has_prev == false
      assert length(loaded.data) == 20
    end

    @tag relations: [:users]
    test "page/2 returns page with custom per_page", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Test first page with custom per_page
      loaded = users.page(1, 10)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 3
      assert loaded.meta.pagination.has_next == true
      assert loaded.meta.pagination.has_prev == false
      assert length(loaded.data) == 10
    end

    @tag relations: [:users]
    test "page/2 returns correct page in middle", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Test middle page
      loaded = users.page(2, 10)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 2
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 3
      assert loaded.meta.pagination.has_next == true
      assert loaded.meta.pagination.has_prev == true
      assert length(loaded.data) == 10
    end

    @tag relations: [:users]
    test "page/2 returns last page correctly", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Test last page
      loaded = users.page(3, 10)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 3
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 3
      assert loaded.meta.pagination.has_next == false
      assert loaded.meta.pagination.has_prev == true
      # remaining records
      assert length(loaded.data) == 5
    end
  end

  describe "per_page functionality" do
    @tag relations: [:users]
    test "per_page/1 sets per_page for subsequent pagination", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Set per_page first
      loaded = users.per_page(5) |> users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 5
      assert loaded.meta.pagination.total_count == 25
      assert loaded.meta.pagination.total_pages == 5
      assert length(loaded.data) == 5
    end

    @tag relations: [:users]
    test "per_page/2 works with existing relations", %{users: users} do
      # Insert test data
      insert_test_users(users, 25)

      # Create base query and add per_page
      base_query = users.restrict(active: true)
      paginated_query = users.per_page(base_query, 3)
      loaded = users.page(paginated_query, 1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 3
      assert loaded.meta.pagination.total_count == 25
      assert length(loaded.data) == 3
    end
  end

  describe "chaining with other operations" do
    @tag relations: [:users]
    test "works with restrict operations", %{users: users} do
      # Insert mixed test data
      insert_test_users(users, 10, active: true)
      insert_test_users(users, 5, active: false)

      # Chain restrict with pagination
      loaded =
        users
        |> users.restrict(active: true)
        |> users.per_page(5)
        |> users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 5
      assert loaded.meta.pagination.total_count == 10
      assert loaded.meta.pagination.total_pages == 2
      assert length(loaded.data) == 5

      # Verify all returned users are active
      assert Enum.all?(loaded.data, & &1.active)
    end

    @tag relations: [:users]
    test "works with order operations", %{users: users} do
      # Insert test data with specific names for ordering
      {:ok, _} = users.insert(%{name: "Charlie", email: "charlie@example.com", active: true})
      {:ok, _} = users.insert(%{name: "Alice", email: "alice@example.com", active: true})
      {:ok, _} = users.insert(%{name: "Bob", email: "bob@example.com", active: true})

      # Chain order with pagination
      loaded =
        users
        |> users.order(:name)
        |> users.per_page(2)
        |> users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 2
      assert loaded.meta.pagination.total_count == 3
      assert loaded.meta.pagination.total_pages == 2
      assert length(loaded.data) == 2

      # Verify ordering
      [first, second] = loaded.data
      assert first.name == "Alice"
      assert second.name == "Bob"
    end
  end

  describe "edge cases" do
    @tag relations: [:users]
    test "handles empty table", %{users: users} do
      loaded = users.page(1)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 20
      assert loaded.meta.pagination.total_count == 0
      assert loaded.meta.pagination.total_pages == 0
      assert loaded.meta.pagination.has_next == false
      assert loaded.meta.pagination.has_prev == false
      assert loaded.data == []
    end

    @tag relations: [:users]
    test "handles page beyond available data", %{users: users} do
      # Insert only 5 records
      insert_test_users(users, 5)

      # Request page 2 with per_page 10 (should be empty)
      loaded = users.page(2, 10)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 2
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 5
      assert loaded.meta.pagination.total_pages == 1
      assert loaded.meta.pagination.has_next == false
      assert loaded.meta.pagination.has_prev == true
      assert loaded.data == []
    end

    @tag relations: [:users]
    test "handles single record", %{users: users} do
      # Insert single record
      {:ok, _} = users.insert(%{name: "Single User", email: "single@example.com", active: true})

      loaded = users.page(1, 10)

      assert %Loaded{} = loaded
      assert loaded.meta.pagination.page == 1
      assert loaded.meta.pagination.per_page == 10
      assert loaded.meta.pagination.total_count == 1
      assert loaded.meta.pagination.total_pages == 1
      assert loaded.meta.pagination.has_next == false
      assert loaded.meta.pagination.has_prev == false
      assert length(loaded.data) == 1
    end
  end

  describe "Enumerable protocol" do
    @tag relations: [:users]
    test "implements Enumerable.count/1", %{users: users} do
      insert_test_users(users, 15)
      loaded = users.page(1, 10)

      assert Enum.count(loaded) == 10
    end

    @tag relations: [:users]
    test "implements Enumerable.member?/2", %{users: users} do
      insert_test_users(users, 5)
      loaded = users.page(1, 10)

      [first_user | _] = loaded.data
      assert Enum.member?(loaded, first_user)

      # Create a user that's not in the loaded data
      {:ok, other_user} = users.insert(%{name: "Other", email: "other@example.com", active: true})
      refute Enum.member?(loaded, other_user)
    end

    @tag relations: [:users]
    test "implements Enumerable.reduce/3", %{users: users} do
      insert_test_users(users, 5)
      loaded = users.page(1, 10)

      # Test map
      names = Enum.map(loaded, & &1.name)
      assert length(names) == 5
      assert Enum.all?(names, &is_binary/1)

      # Test filter
      filtered = Enum.filter(loaded, &String.contains?(&1.name, "User"))
      assert length(filtered) == 5

      # Test reduce
      name_list = Enum.reduce(loaded, [], fn user, acc -> [user.name | acc] end)
      assert length(name_list) == 5
    end

    @tag relations: [:users]
    test "works with Enum.to_list/1", %{users: users} do
      insert_test_users(users, 5)
      loaded = users.page(1, 10)

      user_list = Enum.to_list(loaded)
      assert length(user_list) == 5
      assert user_list == loaded.data
    end

    @tag relations: [:users]
    test "works with Enum.at/2", %{users: users} do
      insert_test_users(users, 5)
      loaded = users.page(1, 10)

      first_user = Enum.at(loaded, 0)
      assert first_user == List.first(loaded.data)

      last_user = Enum.at(loaded, 4)
      assert last_user == List.last(loaded.data)

      assert Enum.at(loaded, 10) == nil
    end
  end

  defp insert_test_users(users, count, attrs \\ []) do
    default_attrs = [active: true]
    attrs = Keyword.merge(default_attrs, attrs)

    # Get current count to ensure unique emails
    current_count = users.count()

    for i <- 1..count do
      unique_id = current_count + i

      user_attrs = %{
        name: "User #{unique_id}",
        email: "user#{unique_id}@example.com",
        active: attrs[:active]
      }

      {:ok, _} = users.insert(user_attrs)
    end
  end
end
