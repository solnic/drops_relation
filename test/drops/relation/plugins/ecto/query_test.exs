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
end
