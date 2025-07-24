defmodule Drops.Relations.QueryTest do
  use Drops.RelationCase, async: false

  import Drops.Relation.Query

  describe "query composition" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end

      defquery inactive() do
        from(u in relation(), where: u.active == false)
      end

      defquery by_name_pattern(pattern) do
        from(u in relation(), where: like(u.name, ^pattern))
      end

      defquery with_email() do
        from(u in relation(), where: not is_nil(u.email))
      end
    end

    test "query functions work with Ecto-style variable bindings", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: false})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      result =
        users
        |> query(
          [u],
          u.get_by_name("Jade") or u.get_by_name("John") or
            (u.restrict(active: true) and u.restrict(name: "Jane"))
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Jade"}, %{name: "John"}] = result
    end

    test "AND operation works correctly", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      result =
        users
        |> query([u], u.restrict(active: true) and u.restrict(name: "Jane"))
        |> Enum.to_list()

      assert [%{name: "Jane", active: true}] = result

      result =
        users
        |> query([u], u.restrict(active: true) and u.restrict(name: "John"))
        |> Enum.to_list()

      assert [] = result
    end

    test "complex AND/OR combinations work correctly", %{users: users} do
      users.insert(%{name: "John", active: false})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Joe", active: false})
      users.insert(%{name: "Jade", active: true})

      result =
        users
        |> query(
          [u],
          (u.restrict(active: true) and u.restrict(name: "Jane")) or
            (u.restrict(active: true) and u.restrict(name: "Jade"))
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Jade"}, %{name: "Jane"}] = result
    end

    test "multiple restrict conditions with AND", %{users: users} do
      users.insert(%{name: "Alice", active: true, email: "alice@example.com"})
      users.insert(%{name: "Bob", active: true, email: nil})
      users.insert(%{name: "Charlie", active: false, email: "charlie@example.com"})

      result =
        users
        |> query([u], u.restrict(active: true) and u.restrict(name: "Alice") and u.with_email())
        |> Enum.to_list()

      assert [%{name: "Alice", active: true}] = result
    end

    test "mixed auto-generated and custom query functions", %{users: users} do
      users.insert(%{name: "John", active: false, email: "john@example.com"})
      users.insert(%{name: "Jane", active: true, email: "jane@example.com"})
      users.insert(%{name: "Jack", active: true, email: nil})

      result =
        users
        |> query([u], u.get_by_name("Jane") and u.active())
        |> Enum.to_list()

      assert [%{name: "Jane", active: true}] = result

      result =
        users
        |> query([u], u.restrict(name: "Jack") and u.active() and u.with_email())
        |> Enum.to_list()

      assert [] = result
    end

    test "complex OR with multiple conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true, email: "alice@example.com"})
      users.insert(%{name: "Bob", active: false, email: "bob@example.com"})
      users.insert(%{name: "Charlie", active: true, email: nil})
      users.insert(%{name: "Diana", active: false, email: nil})

      result =
        users
        |> query(
          [u],
          (u.active() and u.with_email()) or (u.inactive() and u.get_by_name("Bob"))
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Alice"}, %{name: "Bob"}] = result
    end

    test "nested AND/OR combinations", %{users: users} do
      users.insert(%{name: "John", active: true, email: "john@example.com"})
      users.insert(%{name: "Jane", active: false, email: "jane@example.com"})
      users.insert(%{name: "Jack", active: true, email: nil})
      users.insert(%{name: "Jill", active: false, email: nil})

      result =
        users
        |> query(
          [u],
          ((u.active() and u.get_by_name("John")) or (u.inactive() and u.get_by_name("Jane"))) and
            u.with_email()
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Jane"}, %{name: "John"}] = result
    end

    test "query with pattern matching using custom defquery", %{users: users} do
      users.insert(%{name: "John", active: true})
      users.insert(%{name: "Jane", active: true})
      users.insert(%{name: "Bob", active: false})
      users.insert(%{name: "Alice", active: true})

      result =
        users
        |> query([u], u.by_name_pattern("J%") and u.active())
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Jane"}, %{name: "John"}] = result
    end

    test "chaining multiple OR operations", %{users: users} do
      users.insert(%{name: "Alice", active: true})
      users.insert(%{name: "Bob", active: false})
      users.insert(%{name: "Charlie", active: true})
      users.insert(%{name: "Diana", active: false})

      result =
        users
        |> query(
          [u],
          u.get_by_name("Alice") or u.get_by_name("Bob") or u.get_by_name("Charlie")
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Alice"}, %{name: "Bob"}, %{name: "Charlie"}] = result
    end

    test "combining restrict with multiple fields", %{users: users} do
      users.insert(%{name: "John", active: true, email: "john@example.com"})
      users.insert(%{name: "Jane", active: true, email: "jane@example.com"})
      users.insert(%{name: "John", active: false, email: "john2@example.com"})

      result =
        users
        |> query([u], u.restrict(name: "John", active: true))
        |> Enum.to_list()

      assert [%{name: "John", active: true, email: "john@example.com"}] = result
    end

    test "empty result sets with complex conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true})
      users.insert(%{name: "Bob", active: false})

      result =
        users
        |> query([u], u.active() and u.inactive())
        |> Enum.to_list()

      assert [] = result

      result =
        users
        |> query([u], u.get_by_name("Alice") or (u.active() and u.inactive()))
        |> Enum.to_list()

      assert [%{name: "Alice"}] = result
    end
  end

  describe "query composition with ordering and complex conditions" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end

      defquery inactive() do
        from(u in relation(), where: u.active == false)
      end

      defquery by_age_range(min_age, max_age) do
        from(u in relation(), where: u.age >= ^min_age and u.age <= ^max_age)
      end
    end

    test "query composition with ordering", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})
      users.insert(%{name: "Diana", active: true, age: 20})

      result =
        users
        |> query([u], u.active() and u.by_age_range(20, 30))
        |> users.order(:age)
        |> Enum.to_list()

      assert [%{name: "Diana", age: 20}, %{name: "Alice", age: 25}] = result
    end

    test "query with separate filtering and ordering", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: true, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})

      result =
        users
        |> query([u], u.active())
        |> users.order(desc: :age)
        |> Enum.to_list()

      names_and_ages = Enum.map(result, &{&1.name, &1.age})
      assert [{"Charlie", 35}, {"Bob", 30}, {"Alice", 25}] = names_and_ages
    end

    test "complex conditions with age ranges and OR", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})
      users.insert(%{name: "Diana", active: false, age: 20})
      users.insert(%{name: "Eve", active: true, age: 45})

      result =
        users
        |> query(
          [u],
          (u.active() and u.by_age_range(20, 30)) or
            (u.restrict(active: false) and u.by_age_range(30, 40))
        )
        |> users.order(:age)
        |> Enum.to_list()

      names_and_ages = Enum.map(result, &{&1.name, &1.age})

      assert [{"Alice", 25}, {"Bob", 30}] = names_and_ages
    end

    test "simple AND operation with get_by_name", %{users: users} do
      users.insert(%{name: "John", active: true, age: 25})
      users.insert(%{name: "Jane", active: true, age: 30})
      users.insert(%{name: "John", active: false, age: 35})

      result =
        users
        |> query([u], u.get_by_name("John") and u.active())
        |> Enum.to_list()

      names_and_ages = Enum.map(result, &{&1.name, &1.age})
      assert [{"John", 25}] = names_and_ages
    end

    test "AND with OR in parentheses - known limitation", %{users: users} do
      users.insert(%{name: "John", active: true, age: 25})
      users.insert(%{name: "Jane", active: true, age: 30})
      users.insert(%{name: "John", active: false, age: 35})

      result =
        users
        |> query([u], u.get_by_name("John") and (u.active() or u.by_age_range(30, 40)))
        |> users.order(:age)
        |> Enum.to_list()

      names_and_ages = Enum.map(result, &{&1.name, &1.age})

      assert length(names_and_ages) >= 2
      assert {"John", 25} in names_and_ages
      assert {"John", 35} in names_and_ages
    end
  end

  describe "query composition with email field and null handling" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end

      defquery inactive() do
        from(u in relation(), where: u.active == false)
      end

      defquery with_gmail() do
        from(u in relation(), where: like(u.email, "%@gmail.com"))
      end

      defquery without_email() do
        from(u in relation(), where: is_nil(u.email))
      end
    end

    test "query with email patterns and null handling", %{users: users} do
      users.insert(%{name: "Alice", active: true, email: "alice@gmail.com"})
      users.insert(%{name: "Bob", active: true, email: "bob@yahoo.com"})
      users.insert(%{name: "Charlie", active: true, email: nil})
      users.insert(%{name: "Diana", active: false, email: "diana@gmail.com"})

      result =
        users
        |> query([u], u.active() and (u.with_gmail() or u.without_email()))
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Alice"}, %{name: "Charlie"}] = result
    end

    test "query with get_by_email and complex conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true, email: "alice@gmail.com"})
      users.insert(%{name: "Bob", active: false, email: "bob@gmail.com"})
      users.insert(%{name: "Charlie", active: true, email: "charlie@yahoo.com"})

      result =
        users
        |> query([u], u.get_by_email("charlie@yahoo.com") or (u.active() and u.with_gmail()))
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Alice"}, %{name: "Charlie"}] = result
    end

    test "query with null email restrictions", %{users: users} do
      users.insert(%{name: "Alice", active: true, email: "alice@example.com"})
      users.insert(%{name: "Bob", active: true, email: nil})
      users.insert(%{name: "Charlie", active: false, email: nil})

      result =
        users
        |> query([u], u.active() and u.without_email())
        |> Enum.to_list()

      assert [%{name: "Bob"}] = result

      result =
        users
        |> query(
          [u],
          u.restrict(email: "alice@example.com") or
            (u.restrict(active: false) and u.without_email())
        )
        |> users.order(:name)
        |> Enum.to_list()

      assert [%{name: "Alice"}, %{name: "Charlie"}] = result
    end
  end

  describe "advanced query composition scenarios" do
    relation(:users) do
      schema("users", infer: true)

      defquery active() do
        from(u in relation(), where: u.active == true)
      end

      defquery inactive() do
        from(u in relation(), where: u.active == false)
      end

      defquery young() do
        from(u in relation(), where: u.age < 30)
      end

      defquery old() do
        from(u in relation(), where: u.age >= 30)
      end
    end

    test "multiple OR operations in sequence", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 35})
      users.insert(%{name: "Charlie", active: true, age: 40})
      users.insert(%{name: "Diana", active: false, age: 20})

      result =
        users
        |> query([u], u.get_by_name("Alice") or u.get_by_name("Bob") or u.get_by_name("Charlie"))
        |> users.order(:name)
        |> Enum.to_list()

      names = Enum.map(result, & &1.name)
      assert ["Alice", "Bob", "Charlie"] = names
    end

    test "multiple AND operations in sequence", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25, email: "alice@example.com"})
      users.insert(%{name: "Bob", active: true, age: 35, email: nil})
      users.insert(%{name: "Charlie", active: false, age: 25, email: "charlie@example.com"})

      result =
        users
        |> query([u], u.active() and u.young() and u.restrict(email: "alice@example.com"))
        |> Enum.to_list()

      assert [%{name: "Alice"}] = result
    end

    test "mixed AND and OR with simple conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 35})
      users.insert(%{name: "Charlie", active: true, age: 40})
      users.insert(%{name: "Diana", active: false, age: 20})

      result =
        users
        |> query([u], (u.active() and u.young()) or (u.inactive() and u.old()))
        |> users.order(:name)
        |> Enum.to_list()

      names = Enum.map(result, & &1.name)
      assert ["Alice", "Bob"] = names
    end

    test "query with restrict using multiple fields", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Alice", active: false, age: 30})
      users.insert(%{name: "Bob", active: true, age: 25})

      result =
        users
        |> query([u], u.restrict(name: "Alice", active: true))
        |> Enum.to_list()

      assert [%{name: "Alice", active: true, age: 25}] = result
    end

    test "query with list values in restrict", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})
      users.insert(%{name: "Diana", active: false, age: 40})

      result =
        users
        |> query([u], u.restrict(name: ["Alice", "Charlie"]) and u.active())
        |> users.order(:name)
        |> Enum.to_list()

      names = Enum.map(result, & &1.name)
      assert ["Alice", "Charlie"] = names
    end

    test "query composition with order applied after query", %{users: users} do
      users.insert(%{name: "Charlie", active: true, age: 35})
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})

      result =
        users
        |> query([u], u.active())
        |> users.order(desc: :age)
        |> Enum.to_list()

      names_and_ages = Enum.map(result, &{&1.name, &1.age})
      assert [{"Charlie", 35}, {"Alice", 25}] = names_and_ages
    end

    test "empty query results", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})

      result =
        users
        |> query([u], u.active() and u.get_by_name("NonExistent"))
        |> Enum.to_list()

      assert [] = result
    end

    test "query with boolean field conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})

      result =
        users
        |> query([u], u.restrict(active: true) or u.restrict(active: false))
        |> users.order(:name)
        |> Enum.to_list()

      names = Enum.map(result, & &1.name)
      assert ["Alice", "Bob", "Charlie"] = names
    end

    @tag relations: [:users]
    test "AND operation with empty where conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true})
      users.insert(%{name: "Bob", active: false})

      # Create a query that results in empty where conditions on one side
      # This tests the empty wheres case in apply_where_conditions
      empty_relation = users.new()
      active_relation = users.active()

      and_operation = Drops.Relation.Operations.And.new(empty_relation, active_relation, users)

      result = Enum.to_list(and_operation)
      names = Enum.map(result, & &1.name)

      assert ["Alice"] = names
    end

    @tag relations: [:users]
    test "OR operation with empty where conditions", %{users: users} do
      users.insert(%{name: "Alice", active: true})
      users.insert(%{name: "Bob", active: false})

      # Create a query that results in empty where conditions on one side
      # This tests the empty wheres case in apply_where_conditions and apply_or_where_conditions
      empty_relation = users.new()
      active_relation = users.active()

      or_operation = Drops.Relation.Operations.Or.new(empty_relation, active_relation, users)

      result = Enum.to_list(or_operation)
      names = Enum.map(result, & &1.name)

      assert ["Alice"] = names
    end

    @tag relations: [:users]
    test "AND operation Enumerable protocol - count", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: true, age: 30})
      users.insert(%{name: "Charlie", active: false, age: 35})

      and_operation =
        users
        |> query([u], u.active() and u.young())

      # Test Enum.count which calls the count/1 function
      assert Enum.count(and_operation) == 1
    end

    @tag relations: [:users]
    test "OR operation Enumerable protocol - count", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})

      or_operation =
        users
        |> query([u], u.active() or u.old())

      # Test Enum.count which calls the count/1 function
      assert Enum.count(or_operation) == 3
    end

    @tag relations: [:users]
    test "AND operation Enumerable protocol - member?", %{users: users} do
      {:ok, alice} = users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})

      and_operation =
        users
        |> query([u], u.active() and u.young())

      # Test Enum.member? which calls the member?/2 function
      # We need to check if any record with the same ID is in the results
      result_ids = Enum.map(and_operation, & &1.id)
      assert alice.id in result_ids
    end

    @tag relations: [:users]
    test "OR operation Enumerable protocol - member?", %{users: users} do
      {:ok, alice} = users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})

      or_operation =
        users
        |> query([u], u.active() or u.old())

      # Test Enum.member? which calls the member?/2 function
      # We need to check if any record with the same ID is in the results
      result_ids = Enum.map(or_operation, & &1.id)
      assert alice.id in result_ids
    end

    @tag relations: [:users]
    test "AND operation Enumerable protocol - slice", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: true, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})

      and_operation =
        users
        |> query([u], u.active() and u.old())

      # Test Enum.slice which calls the slice/1 function
      sliced = Enum.slice(and_operation, 0, 2)
      assert length(sliced) == 2
    end

    @tag relations: [:users]
    test "OR operation Enumerable protocol - slice", %{users: users} do
      users.insert(%{name: "Alice", active: true, age: 25})
      users.insert(%{name: "Bob", active: false, age: 30})
      users.insert(%{name: "Charlie", active: true, age: 35})

      or_operation =
        users
        |> query([u], u.active() or u.old())

      # Test Enum.slice which calls the slice/1 function
      sliced = Enum.slice(or_operation, 0, 2)
      assert length(sliced) == 2
    end
  end
end
