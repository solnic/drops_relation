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
end
