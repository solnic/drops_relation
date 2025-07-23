defmodule Drops.Relations.Plugins.ReadingTest do
  use Drops.RelationCase, async: false

  describe "query API functions" do
    @tag relations: [:users]
    test "query functions work with actual data", %{users: users} do
      # Test count on empty table
      assert users.count() == 0

      # Test all on empty table
      assert users.all() == []

      # Insert a user using Ecto changeset to handle timestamps properly
      user_struct = users.struct(%{name: "Test User", email: "test@example.com"})
      changeset = Ecto.Changeset.cast(user_struct, %{}, [:name, :email])
      {:ok, _} = users.insert(changeset)

      # Get the inserted user to test with
      [user] = users.all()
      assert user.name == "Test User"

      # Test count after insert
      assert users.count() == 1

      # Test get
      found_user = users.get(user.id)
      assert found_user.name == "Test User"
      assert found_user.email == "test@example.com"

      # Test get_by - returns a record (standard Ecto.Repo interface)
      found_by_email = users.get_by(email: "test@example.com")
      assert found_by_email.id == user.id

      # Test all
      all_users = users.all()
      assert length(all_users) == 1
      assert hd(all_users).id == user.id

      # Test update (using changeset)
      changeset = Ecto.Changeset.change(user, %{name: "Updated User"})
      {:ok, updated_user} = users.update(changeset)
      assert updated_user.name == "Updated User"

      # Test delete
      {:ok, _deleted_user} = users.delete(updated_user)
      assert users.count() == 0
    end
  end

  describe "index-based finders" do
    @tag relations: [:users]
    test "generates get_by_{field} functions for indexed fields", %{users: users} do
      user_struct = users.struct(%{name: "testuser", email: "test@example.com"})
      changeset = Ecto.Changeset.cast(user_struct, %{}, [:name, :email])

      {:ok, inserted_user} = users.insert(changeset)

      # Test the index-based finders - they now return relations
      user_by_email = users.get_by_email("test@example.com")
      assert user_by_email != nil
      assert is_struct(user_by_email)

      # Get the actual record from the relation
      user_record = Enum.at(user_by_email, 0)
      assert user_record.name == "testuser"

      user_by_name = users.get_by_name("testuser")
      assert user_by_name != nil
      assert is_struct(user_by_name)

      # Get the actual record from the relation
      name_record = Enum.at(user_by_name, 0)
      assert name_record.email == "test@example.com"
      assert name_record.id == inserted_user.id
    end
  end

  describe "nested Schema module" do
    @tag relations: [:users]
    test "generates proper Ecto.Schema module", %{users: users} do
      schema_module = users.__schema_module__()
      assert Code.ensure_loaded?(schema_module)

      # Test Ecto.Schema functions
      assert users.__schema__(:source) == "users"
      assert :id in users.__schema__(:fields)
      assert :name in users.__schema__(:fields)
      assert :email in users.__schema__(:fields)

      # Test that we can create structs (using apply to avoid compile-time issues)
      user_struct = struct(schema_module, %{name: "Test", email: "test@example.com"})
      assert user_struct.name == "Test"
      assert user_struct.email == "test@example.com"

      # Test that the struct works with Ecto.Repo functions
      {:ok, inserted_user} = users.insert(user_struct)
      assert inserted_user.name == "Test"
      assert inserted_user.email == "test@example.com"
    end
  end

  describe "parent module schema() function" do
    @tag relations: [:users]
    test "provides access to Drops.Relation.Schema", %{users: users} do
      schema = users.schema()
      assert schema.__struct__ == Drops.Relation.Schema
      assert schema.source == :users
      assert length(schema.fields) > 0

      # Check that fields contain expected field structs
      field_names = Enum.map(schema.fields, & &1.name)
      assert :id in field_names
      assert :name in field_names
      assert :email in field_names
    end
  end

  describe "all_by/2 function" do
    @tag relations: [:users]
    test "fetches all records matching clauses", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "Active User 1", email: "user1@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Active User 2", email: "user2@example.com", active: true})

      {:ok, _user3} =
        users.insert(%{name: "Inactive User", email: "user3@example.com", active: false})

      # Test all_by with single condition
      active_users = users.all_by(active: true)
      assert length(active_users) == 2
      assert Enum.all?(active_users, & &1.active)

      # Test all_by with multiple conditions
      specific_user = users.all_by(name: "Active User 1", active: true)
      assert length(specific_user) == 1
      assert hd(specific_user).name == "Active User 1"

      # Test all_by with no matches
      no_matches = users.all_by(name: "Nonexistent")
      assert no_matches == []
    end
  end

  describe "new query functions" do
    @tag relations: [:users]
    test "exists? function works", %{users: users} do
      # Test on empty table
      refute users.exists?()

      # Insert a user
      {:ok, _user} = users.insert(%{name: "Test User", email: "test@example.com"})

      # Test exists? returns true
      assert users.exists?()
    end

    @tag relations: [:users]
    test "aggregate functions work", %{users: users} do
      # Insert test data with ages
      {:ok, _user1} = users.insert(%{name: "User 1", email: "user1@example.com", age: 25})
      {:ok, _user2} = users.insert(%{name: "User 2", email: "user2@example.com", age: 30})
      {:ok, _user3} = users.insert(%{name: "User 3", email: "user3@example.com", age: 35})

      # Test aggregate with field
      avg_age = users.aggregate(:avg, :age)
      assert avg_age == 30.0

      max_age = users.aggregate(:max, :age)
      assert max_age == 35

      min_age = users.aggregate(:min, :age)
      assert min_age == 25
    end

    @tag relations: [:users]
    test "delete_all function works", %{users: users} do
      # Insert test data
      {:ok, _user1} = users.insert(%{name: "User 1", email: "user1@example.com"})
      {:ok, _user2} = users.insert(%{name: "User 2", email: "user2@example.com"})

      assert users.count() == 2

      # Delete all users
      {count, _} = users.delete_all()
      assert count == 2
      assert users.count() == 0
    end

    @tag relations: [:users]
    test "update_all function works", %{users: users} do
      # Insert test data
      {:ok, _user1} = users.insert(%{name: "User 1", email: "user1@example.com", active: false})
      {:ok, _user2} = users.insert(%{name: "User 2", email: "user2@example.com", active: false})

      # Update all users to active
      {count, _} = users.update_all(set: [active: true])
      assert count == 2

      # Verify all users are now active
      active_users = users.all_by(active: true)
      assert length(active_users) == 2
    end
  end

  describe "order/1" do
    @tag relations: [:users]
    test "ordering by single field", %{users: users} do
      users.insert(%{name: "Charlie", email: "charlie@example.com"})
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Test ordering by name ascending
      relation = users |> users.order(:name)
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 1).name == "Bob"
      assert Enum.at(ordered_users, 2).name == "Charlie"
    end

    @tag relations: [:users]
    test "ordering by multiple fields", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Test ordering by name then email
      relation = users |> users.order([:name, :email])
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 0).email == "alice1@example.com"
      assert Enum.at(ordered_users, 1).name == "Alice"
      assert Enum.at(ordered_users, 1).email == "alice2@example.com"
      assert Enum.at(ordered_users, 2).name == "Bob"
    end

    @tag relations: [:users]
    test "composing order with restrict", %{users: users} do
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})
      users.insert(%{name: "Charlie", email: "charlie@example.com"})

      # Test composing order with restrict
      relation =
        users
        |> users.restrict(name: "Alice")
        |> users.order(:email)

      ordered_users = Enum.to_list(relation)
      assert length(ordered_users) == 1
      assert Enum.at(ordered_users, 0).name == "Alice"
    end

    @tag relations: [:users]
    test "chaining multiple order calls", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Test chaining multiple order calls
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
    test "ordering with keyword list directions", %{users: users} do
      users.insert(%{name: "Alice", email: "alice@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})
      users.insert(%{name: "Charlie", email: "charlie@example.com"})

      # Test ordering with desc direction
      relation = users |> users.order(desc: :name)
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      assert Enum.at(ordered_users, 0).name == "Charlie"
      assert Enum.at(ordered_users, 1).name == "Bob"
      assert Enum.at(ordered_users, 2).name == "Alice"
    end

    @tag relations: [:users]
    test "ordering with mixed directions", %{users: users} do
      users.insert(%{name: "Alice", email: "alice2@example.com"})
      users.insert(%{name: "Alice", email: "alice1@example.com"})
      users.insert(%{name: "Bob", email: "bob@example.com"})

      # Test ordering with mixed directions
      relation = users |> users.order(asc: :name, desc: :email)
      ordered_users = Enum.to_list(relation)

      assert length(ordered_users) == 3
      # Should be ordered by name asc, then email desc
      assert Enum.at(ordered_users, 0).name == "Alice"
      assert Enum.at(ordered_users, 0).email == "alice2@example.com"
      assert Enum.at(ordered_users, 1).name == "Alice"
      assert Enum.at(ordered_users, 1).email == "alice1@example.com"
      assert Enum.at(ordered_users, 2).name == "Bob"
    end
  end

  describe "restrict/2 with advanced field filtering" do
    @tag relations: [:users]
    test "handles list values with IN expressions", %{users: users} do
      # Insert test data
      {:ok, _user1} = users.insert(%{name: "Alice", email: "alice@example.com", active: true})
      {:ok, _user2} = users.insert(%{name: "Bob", email: "bob@example.com", active: false})
      {:ok, _user3} = users.insert(%{name: "Charlie", email: "charlie@example.com", active: true})

      # Test list values (should use IN clause)
      relation = users.restrict(name: ["Alice", "Charlie"])
      found_users = Enum.to_list(relation)

      assert length(found_users) == 2
      names = Enum.map(found_users, & &1.name)
      assert "Alice" in names
      assert "Charlie" in names
      refute "Bob" in names
    end

    @tag relations: [:users]
    test "handles boolean values correctly", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "Active User", email: "active@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Inactive User", email: "inactive@example.com", active: false})

      # Test boolean true
      active_relation = users.restrict(active: true)
      active_users = Enum.to_list(active_relation)
      assert length(active_users) == 1
      assert hd(active_users).name == "Active User"

      # Test boolean false
      inactive_relation = users.restrict(active: false)
      inactive_users = Enum.to_list(inactive_relation)
      assert length(inactive_users) == 1
      assert hd(inactive_users).name == "Inactive User"
    end

    @tag relations: [:users]
    test "handles nil values with is_nil expressions", %{users: users} do
      # Insert test data with some nil ages
      {:ok, _user1} = users.insert(%{name: "User with age", email: "user1@example.com", age: 25})

      {:ok, _user2} =
        users.insert(%{name: "User without age", email: "user2@example.com", age: nil})

      # Test nil values (should use is_nil)
      relation = users.restrict(age: nil)
      found_users = Enum.to_list(relation)

      assert length(found_users) == 1
      assert hd(found_users).name == "User without age"
      assert hd(found_users).age == nil
    end

    @tag relations: [:users]
    test "raises error on invalid fields", %{users: users} do
      assert_raise Drops.Relation.Plugins.Queryable.InvalidQueryError, ~r/invalid_field/, fn ->
        users.restrict(name: "Test User", invalid_field: "some_value") |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "combines multiple field types in single restrict", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "Alice", email: "alice@example.com", active: true, age: 25})

      {:ok, _user2} =
        users.insert(%{name: "Bob", email: "bob@example.com", active: true, age: nil})

      {:ok, _user3} =
        users.insert(%{name: "Charlie", email: "charlie@example.com", active: false, age: 30})

      # Test combining list, boolean, and nil values
      relation = users.restrict(name: ["Alice", "Bob"], active: true, age: nil)
      found_users = Enum.to_list(relation)

      assert length(found_users) == 1
      assert hd(found_users).name == "Bob"
      assert hd(found_users).active == true
      assert hd(found_users).age == nil
    end

    @tag relations: [:users]
    test "sets operation metadata correctly", %{users: users} do
      # Test that restrict sets the operations field
      relation = users.restrict(name: "Test")
      assert relation.operations == [:restrict]

      # Test that order sets the operations field
      order_relation = users.order(:name)
      assert order_relation.operations == [:order]

      # Test that chaining operations accumulates them
      chained_relation = users.restrict(name: "Test") |> users.order(:name)
      assert chained_relation.operations == [:restrict, :order]
    end
  end

  describe "preload operations" do
    relation(:association_parents) do
      schema("association_parents", infer: true)
    end

    relation(:association_items) do
      schema("association_items") do
        belongs_to(:association, Test.Relations.Associations)
      end
    end

    relation(:associations) do
      schema("associations") do
        has_many(:items, Test.Relations.AssociationItems)
        belongs_to(:parent, Test.Relations.AssociationParents)
      end
    end

    test "preloads single association", %{
      associations: associations,
      association_parents: parents
    } do
      # Create test data
      {:ok, parent} = parents.insert(%{description: "Test Parent"})
      {:ok, _association} = associations.insert(%{name: "Test Association", parent_id: parent.id})

      # Test preload with single association
      result = associations.preload(:parent) |> associations.all()

      assert length(result) == 1
      loaded_association = List.first(result)
      assert loaded_association.name == "Test Association"
      assert loaded_association.parent.description == "Test Parent"
    end

    test "preloads multiple associations", %{
      associations: associations,
      association_items: items,
      association_parents: parents
    } do
      # Create test data
      {:ok, parent} = parents.insert(%{description: "Test Parent"})
      {:ok, association} = associations.insert(%{name: "Test Association", parent_id: parent.id})
      {:ok, _item} = items.insert(%{title: "Test Item", association_id: association.id})

      # Test preload with multiple associations
      result = associations.preload([:parent, :items]) |> associations.all()

      assert length(result) == 1
      loaded_association = List.first(result)
      assert loaded_association.name == "Test Association"
      assert loaded_association.parent.description == "Test Parent"
      assert length(loaded_association.items) == 1
      assert List.first(loaded_association.items).title == "Test Item"
    end

    test "combines preload with restrict", %{
      associations: associations,
      association_parents: parents
    } do
      # Create test data
      {:ok, parent1} = parents.insert(%{description: "Parent 1"})
      {:ok, parent2} = parents.insert(%{description: "Parent 2"})
      {:ok, _assoc1} = associations.insert(%{name: "Association 1", parent_id: parent1.id})
      {:ok, _assoc2} = associations.insert(%{name: "Association 2", parent_id: parent2.id})

      # Test combining preload with restrict
      result =
        associations
        |> associations.restrict(name: "Association 1")
        |> associations.preload(:parent)
        |> associations.all()

      assert length(result) == 1
      loaded_association = List.first(result)
      assert loaded_association.name == "Association 1"
      assert loaded_association.parent.description == "Parent 1"
    end
  end

  describe "nullable field handling in restrict" do
    @tag relations: [:users]
    test "handles nil values for nullable fields", %{users: users} do
      # Create test data with nil email (assuming email is nullable)
      {:ok, _user1} = users.insert(%{name: "User 1", email: nil})
      {:ok, _user2} = users.insert(%{name: "User 2", email: "user2@example.com"})

      # Test restricting by nil value
      result = users.restrict(email: nil) |> users.all()

      assert length(result) == 1
      assert List.first(result).name == "User 1"
    end

    @tag relations: [:users]
    test "handles list values with in clause", %{users: users} do
      # Create test data
      {:ok, _user1} = users.insert(%{name: "User 1", email: "user1@example.com"})
      {:ok, _user2} = users.insert(%{name: "User 2", email: "user2@example.com"})
      {:ok, _user3} = users.insert(%{name: "User 3", email: "user3@example.com"})

      # Test restricting by list of values
      result = users.restrict(email: ["user1@example.com", "user2@example.com"]) |> users.all()

      assert length(result) == 2
      names = Enum.map(result, & &1.name) |> Enum.sort()
      assert names == ["User 1", "User 2"]
    end
  end

  describe "transaction functions" do
    @tag relations: [:users]
    test "transaction function works", %{users: users} do
      result =
        users.transaction(fn ->
          {:ok, user1} = users.insert(%{name: "User 1", email: "user1@example.com"})
          {:ok, user2} = users.insert(%{name: "User 2", email: "user2@example.com"})
          [user1, user2]
        end)

      assert {:ok, [user1, user2]} = result
      assert user1.name == "User 1"
      assert user2.name == "User 2"
      assert users.count() == 2
    end

    @tag relations: [:users]
    test "in_transaction? function works", %{users: users} do
      # Outside transaction
      refute users.in_transaction?()

      # Inside transaction
      users.transaction(fn ->
        assert users.in_transaction?()
        {:ok, :test}
      end)
    end
  end

  describe "query validation errors" do
    alias Drops.Relation.Plugins.Queryable.InvalidQueryError

    relation(:metadata_test) do
      schema("metadata_test", infer: true)
    end

    test "raises InvalidQueryError when comparing nil to non-nullable field", %{
      metadata_test: metadata_test
    } do
      # The 'name' field in metadata_test is non-nullable
      assert_raise InvalidQueryError, ~r/name is not nullable/, fn ->
        metadata_test.restrict(name: nil) |> Enum.to_list()
      end
    end

    test "raises InvalidQueryError when comparing boolean to non-boolean field", %{
      metadata_test: metadata_test
    } do
      # The 'name' field is a string field, not boolean
      assert_raise InvalidQueryError, ~r/name is not a boolean field/, fn ->
        metadata_test.restrict(name: true) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "raises InvalidQueryError when ordering by non-existent field", %{users: users} do
      assert_raise InvalidQueryError, ~r/Field 'nonexistent' not found in schema/, fn ->
        users.order(:nonexistent) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "raises InvalidQueryError when ordering with invalid specification", %{users: users} do
      assert_raise InvalidQueryError, ~r/invalid order specification/, fn ->
        users.order([{:invalid_direction, :name}]) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "raises InvalidQueryError when preloading non-existent association", %{users: users} do
      assert_raise InvalidQueryError, ~r/association :nonexistent is not defined/, fn ->
        users.preload(:nonexistent) |> Enum.to_list()
      end
    end

    @tag relations: [:users]
    test "allows nil comparison for nullable fields", %{users: users} do
      # The 'age' field in users is nullable
      # This should not raise an error
      result = users.restrict(age: nil) |> Enum.to_list()
      assert is_list(result)
    end

    test "raises InvalidQueryError for non-boolean fields with integer defaults", %{
      metadata_test: metadata_test
    } do
      # The 'is_enabled' field has default: 1 (integer), so it's NOT a boolean field
      # This should raise an error
      assert_raise InvalidQueryError, ~r/is_enabled is not a boolean field/, fn ->
        metadata_test.restrict(is_enabled: true) |> Enum.to_list()
      end
    end

    relation(:custom_types) do
      schema("custom_types", infer: true)
    end

    test "allows boolean comparison for proper boolean fields", %{custom_types: custom_types} do
      # The 'boolean_true_default' field has default: true, so it IS a boolean field
      # This should not raise an error
      result = custom_types.restrict(boolean_true_default: true) |> Enum.to_list()
      assert is_list(result)

      # Test false value as well
      result = custom_types.restrict(boolean_false_default: false) |> Enum.to_list()
      assert is_list(result)
    end

    test "error message includes multiple validation errors", %{metadata_test: metadata_test} do
      assert_raise InvalidQueryError, fn ->
        metadata_test.restrict(name: nil, nonexistent_field: "value") |> Enum.to_list()
      end
    end

    test "validation errors are human-readable", %{metadata_test: metadata_test} do
      try do
        metadata_test.restrict(name: nil) |> Enum.to_list()
        flunk("Expected InvalidQueryError to be raised")
      rescue
        error in InvalidQueryError ->
          message = Exception.message(error)
          assert message =~ "Query validation failed"
          assert message =~ "name is not nullable"
          assert message =~ "comparing to `nil` is not allowed"
      end
    end
  end

  describe "relation struct support for query functions" do
    @tag relations: [:users]
    test "count/2 works with relation structs", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "Active User", email: "active@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Inactive User", email: "inactive@example.com", active: false})

      # Test count with relation struct
      active_query = users.restrict(active: true)
      count = users.count(active_query)
      assert count == 1

      # Test count with piped syntax
      count_piped = users.restrict(active: true) |> users.count()
      assert count_piped == 1
    end

    @tag relations: [:users]
    test "first/2 works with relation structs", %{users: users} do
      # Insert test data in specific order
      {:ok, _user1} = users.insert(%{name: "Alice", email: "alice@example.com", active: true})
      {:ok, _user2} = users.insert(%{name: "Bob", email: "bob@example.com", active: true})

      # Test first with relation struct
      active_query = users.restrict(active: true) |> users.order(:name)
      first_user = users.first(active_query)
      assert first_user.name == "Alice"

      # Test first with piped syntax
      first_piped = users.restrict(active: true) |> users.order(:name) |> users.first()
      assert first_piped.name == "Alice"
    end

    @tag relations: [:users]
    test "last/2 works with relation structs", %{users: users} do
      # Insert test data in specific order
      {:ok, _user1} = users.insert(%{name: "Alice", email: "alice@example.com", active: true})
      {:ok, _user2} = users.insert(%{name: "Bob", email: "bob@example.com", active: true})

      # Test last with relation struct
      active_query = users.restrict(active: true) |> users.order(:name)
      last_user = users.last(active_query)
      assert last_user.name == "Bob"

      # Test last with piped syntax
      last_piped = users.restrict(active: true) |> users.order(:name) |> users.last()
      assert last_piped.name == "Bob"
    end

    @tag relations: [:users]
    test "one/2 works with relation structs", %{users: users} do
      # Insert single matching record
      {:ok, _user1} =
        users.insert(%{name: "Unique User", email: "unique@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Other User", email: "other@example.com", active: false})

      # Test one with relation struct
      unique_query = users.restrict(active: true)
      user = users.one(unique_query)
      assert user.name == "Unique User"

      # Test one with piped syntax
      user_piped = users.restrict(active: true) |> users.one()
      assert user_piped.name == "Unique User"
    end

    @tag relations: [:users]
    test "one!/2 works with relation structs", %{users: users} do
      # Insert single matching record
      {:ok, _user1} =
        users.insert(%{name: "Unique User", email: "unique@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Other User", email: "other@example.com", active: false})

      # Test one! with relation struct
      unique_query = users.restrict(active: true)
      user = users.one!(unique_query)
      assert user.name == "Unique User"

      # Test one! with piped syntax
      user_piped = users.restrict(active: true) |> users.one!()
      assert user_piped.name == "Unique User"
    end
  end

  describe "aggregation shortcut functions" do
    @tag relations: [:users]
    test "min/2 and min/3 work correctly", %{users: users} do
      # Insert test data with ages
      {:ok, _user1} =
        users.insert(%{name: "User 1", email: "user1@example.com", age: 25, active: true})

      {:ok, _user2} =
        users.insert(%{name: "User 2", email: "user2@example.com", age: 30, active: true})

      {:ok, _user3} =
        users.insert(%{name: "User 3", email: "user3@example.com", age: 35, active: false})

      # Test min without relation struct
      min_age = users.min(:age)
      assert min_age == 25

      # Test min with relation struct
      active_query = users.restrict(active: true)
      min_active_age = users.min(active_query, :age)
      assert min_active_age == 25

      # Test min with piped syntax
      min_piped = users.restrict(active: true) |> users.min(:age)
      assert min_piped == 25
    end

    @tag relations: [:users]
    test "max/2 and max/3 work correctly", %{users: users} do
      # Insert test data with ages
      {:ok, _user1} =
        users.insert(%{name: "User 1", email: "user1@example.com", age: 25, active: true})

      {:ok, _user2} =
        users.insert(%{name: "User 2", email: "user2@example.com", age: 30, active: true})

      {:ok, _user3} =
        users.insert(%{name: "User 3", email: "user3@example.com", age: 35, active: false})

      # Test max without relation struct
      max_age = users.max(:age)
      assert max_age == 35

      # Test max with relation struct
      active_query = users.restrict(active: true)
      max_active_age = users.max(active_query, :age)
      assert max_active_age == 30

      # Test max with piped syntax
      max_piped = users.restrict(active: true) |> users.max(:age)
      assert max_piped == 30
    end

    @tag relations: [:users]
    test "sum/2 and sum/3 work correctly", %{users: users} do
      # Insert test data with ages
      {:ok, _user1} =
        users.insert(%{name: "User 1", email: "user1@example.com", age: 25, active: true})

      {:ok, _user2} =
        users.insert(%{name: "User 2", email: "user2@example.com", age: 30, active: true})

      {:ok, _user3} =
        users.insert(%{name: "User 3", email: "user3@example.com", age: 35, active: false})

      # Test sum without relation struct
      sum_age = users.sum(:age)
      assert sum_age == 90

      # Test sum with relation struct
      active_query = users.restrict(active: true)
      sum_active_age = users.sum(active_query, :age)
      assert sum_active_age == 55

      # Test sum with piped syntax
      sum_piped = users.restrict(active: true) |> users.sum(:age)
      assert sum_piped == 55
    end

    @tag relations: [:users]
    test "avg/2 and avg/3 work correctly", %{users: users} do
      # Insert test data with ages
      {:ok, _user1} =
        users.insert(%{name: "User 1", email: "user1@example.com", age: 25, active: true})

      {:ok, _user2} =
        users.insert(%{name: "User 2", email: "user2@example.com", age: 30, active: true})

      {:ok, _user3} =
        users.insert(%{name: "User 3", email: "user3@example.com", age: 35, active: false})

      # Test avg without relation struct
      avg_age = users.avg(:age)
      assert avg_age == 30.0

      # Test avg with relation struct
      active_query = users.restrict(active: true)
      avg_active_age = users.avg(active_query, :age)
      assert avg_active_age == 27.5

      # Test avg with piped syntax
      avg_piped = users.restrict(active: true) |> users.avg(:age)
      assert avg_piped == 27.5
    end
  end
end
