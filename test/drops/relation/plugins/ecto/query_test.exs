defmodule Drops.Relations.Plugins.Ecto.QueryTest do
  use Drops.RelationCase, async: false

  describe "query/1 with no args" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end
    end

    test "defines a custom query accessible via relation module", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})

      assert [%{name: "Jane"}] = users.active() |> Enum.to_list()
    end

    test "composes with relations", %{users: users} do
      users.insert(%{name: "Jade", active: false})

      {:ok, jade} = users.insert(%{name: "Jade", active: true})

      assert [%{name: "Jade"} = user] =
               users.active() |> users.get_by_name("Jade") |> Enum.to_list()

      assert jade.id == user.id
    end
  end

  describe "query/1 with args" do
    relation(:users) do
      schema("users", infer: true)

      defquery by_name(names) when is_list(names) do
        from(u in relation(), where: u.name in ^names)
      end

      defquery by_name(names) do
        from(u in relation(), where: u.name == ^names)
      end

      defquery by_age(age) do
        from(u in relation(), where: u.age == ^age)
      end

      defquery order(field) do
        from(u in relation(), order_by: [^field])
      end

      defquery paginate(offset, per_page) do
        from(q in relation(), offset: ^offset, limit: ^per_page)
      end
    end

    test "defines a custom query with args", %{users: users} do
      users.insert(%{name: "John", active: false, age: 31})
      users.insert(%{name: "Jane", active: true, age: 42})

      assert [%{name: "John"}] = users.by_name("John") |> Enum.to_list()
      assert [%{name: "Jane"}] = users.by_name("Jane") |> Enum.to_list()
    end

    test "composes multiple queries", %{users: users} do
      users.insert(%{name: "John", active: false, age: 31})
      users.insert(%{name: "Jane", active: false, age: 42})
      users.insert(%{name: "John", active: true, age: 42})

      assert [%{name: "John", age: 42}] =
               users.by_name("John") |> users.by_age(42) |> users.order(:name) |> Enum.to_list()

      assert [%{name: "Jane", age: 42}, %{name: "John", age: 42}] =
               users.by_name(["John", "Jane"])
               |> users.by_age(42)
               |> users.order(:name)
               |> Enum.to_list()
    end
  end

  describe "query/1 with multiple args" do
    relation(:users) do
      schema("users", infer: true)

      defquery by_age(age) do
        from(u in relation(), where: u.age == ^age)
      end

      defquery paginate(offset, per_page) do
        from(q in relation(), offset: ^offset, limit: ^per_page)
      end
    end

    test "defines a custom query with multiple args", %{users: users} do
      Enum.each(1..25, fn i ->
        users.insert(%{name: "User #{i}", active: true, age: 20 + i})
      end)

      result = users.paginate(5, 10) |> Enum.to_list()
      assert length(result) == 10
    end

    test "composes with other relations (multiple args)", %{users: users} do
      Enum.each(1..25, fn i ->
        users.insert(%{name: "User #{i}", active: true, age: 20 + i})
      end)

      base_query = users.by_age(25)
      result = users.paginate(base_query, 0, 5) |> Enum.to_list()
      assert length(result) == 1
      assert [%{age: 25}] = result
    end
  end

  describe "query/1 with guards" do
    relation(:users) do
      schema("users", infer: true)

      defquery by_age_range(min_age, max_age) do
        from(u in relation(), where: u.age >= ^min_age and u.age <= ^max_age)
      end

      defquery by_status(status) when status in [:active, :inactive] do
        active_value = if status == :active, do: true, else: false
        from(u in relation(), where: u.active == ^active_value)
      end
    end

    test "query with multiple arguments works", %{users: users} do
      users.insert(%{name: "Young User", active: true, age: 25})
      users.insert(%{name: "Old User", active: true, age: 150})

      # Test with both min_age and max_age
      result = users.by_age_range(20, 100) |> Enum.to_list()
      assert length(result) == 1
      assert [%{name: "Young User"}] = result
    end

    test "query with guards works", %{users: users} do
      users.insert(%{name: "Active User", active: true, age: 25})
      users.insert(%{name: "Inactive User", active: false, age: 30})

      # Test with valid guard value
      active_result = users.by_status(:active) |> Enum.to_list()
      assert length(active_result) == 1
      assert [%{name: "Active User"}] = active_result

      inactive_result = users.by_status(:inactive) |> Enum.to_list()
      assert length(inactive_result) == 1
      assert [%{name: "Inactive User"}] = inactive_result
    end
  end

  describe "query composition with relation operations" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end

      defquery by_name_pattern(pattern) do
        from(u in relation(), where: like(u.name, ^pattern))
      end
    end

    test "custom queries compose with restrict", %{users: users} do
      users.insert(%{name: "Active Alice", active: true, age: 25})
      users.insert(%{name: "Active Bob", active: true, age: 30})
      users.insert(%{name: "Inactive Alice", active: false, age: 25})

      result =
        users.active()
        |> users.restrict(age: 25)
        |> Enum.to_list()

      assert length(result) == 1
      assert [%{name: "Active Alice"}] = result
    end

    test "custom queries compose with order", %{users: users} do
      users.insert(%{name: "Charlie", active: true, age: 35})
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: true, age: 30})

      result =
        users.active()
        |> users.order(:name)
        |> Enum.to_list()

      names = Enum.map(result, & &1.name)
      assert names == ["Alice", "Bob", "Charlie"]
    end

    test "multiple custom queries can be chained", %{users: users} do
      users.insert(%{name: "Active Alice", active: true, age: 25})
      users.insert(%{name: "Active Bob", active: true, age: 30})
      users.insert(%{name: "Inactive Alice", active: false, age: 25})

      result =
        users.active()
        |> users.by_name_pattern("%Alice%")
        |> Enum.to_list()

      assert length(result) == 1
      assert [%{name: "Active Alice"}] = result
    end
  end

  describe "error handling" do
    relation(:users) do
      schema("users", infer: true)

      defquery invalid_field_query() do
        from(u in relation(), where: u.nonexistent_field == "test")
      end
    end

    test "queries with invalid fields raise appropriate errors", %{users: users} do
      # This should raise an error when the query is executed
      assert_raise Ecto.QueryError, fn ->
        users.invalid_field_query() |> Enum.to_list()
      end
    end
  end
end
