defmodule Drops.Relations.Plugins.WritingTest do
  use Test.RelationCase, async: false

  describe "changeset/2 function" do
    @tag relations: [:users]
    test "creates changeset from map", %{users: users} do
      params = %{name: "John", email: "john@example.com", age: 30}
      changeset = users.changeset(params)

      assert changeset.__struct__ == Ecto.Changeset
      assert changeset.valid?
      assert changeset.changes.name == "John"
      assert changeset.changes.email == "john@example.com"
      assert changeset.changes.age == 30
    end

    @tag relations: [:users]
    test "creates changeset from struct with changes", %{users: users} do
      # First create a user
      {:ok, user} = users.insert(%{name: "Jane", email: "jane@example.com"})

      # Then create changeset with changes
      changeset = users.changeset(user, %{name: "Jane Updated"})

      assert changeset.__struct__ == Ecto.Changeset
      assert changeset.valid?
      assert changeset.changes.name == "Jane Updated"
      assert changeset.data.id == user.id
    end

    @tag relations: [:users]
    test "changeset can be used with insert", %{users: users} do
      changeset = users.changeset(%{name: "Bob", email: "bob@example.com"})
      {:ok, user} = users.insert(changeset)

      assert user.name == "Bob"
      assert user.email == "bob@example.com"
    end
  end

  describe "update functions" do
    @tag relations: [:users]
    test "update accepts changeset", %{users: users} do
      {:ok, user} = users.insert(%{name: "Alice", email: "alice@example.com"})

      changeset = users.changeset(user, %{name: "Alice Updated"})
      {:ok, updated_user} = users.update(changeset)

      assert updated_user.name == "Alice Updated"
      assert updated_user.id == user.id
    end

    @tag relations: [:users]
    test "update accepts struct and attributes", %{users: users} do
      {:ok, user} = users.insert(%{name: "Charlie", email: "charlie@example.com"})

      # Update with struct and attributes
      {:ok, updated_user} = users.update(user, %{name: "Charlie Updated"})

      assert updated_user.name == "Charlie Updated"
      assert updated_user.id == user.id
    end
  end

  describe "update! functions" do
    @tag relations: [:users]
    test "update! accepts struct and attributes", %{users: users} do
      {:ok, user} = users.insert(%{name: "David", email: "david@example.com"})

      # Update with struct and attributes
      updated_user = users.update!(user, %{name: "David Updated"})

      assert updated_user.name == "David Updated"
      assert updated_user.id == user.id
    end

    @tag relations: [:users]
    test "update! accepts changeset", %{users: users} do
      {:ok, user} = users.insert(%{name: "Eve", email: "eve@example.com"})

      changeset = users.changeset(user, %{name: "Eve Updated"})
      updated_user = users.update!(changeset)

      assert updated_user.name == "Eve Updated"
      assert updated_user.id == user.id
    end
  end

  describe "delete functions" do
    @tag relations: [:users]
    test "delete accepts struct", %{users: users} do
      {:ok, user} = users.insert(%{name: "Frank", email: "frank@example.com"})

      {:ok, deleted_user} = users.delete(user)

      assert deleted_user.id == user.id
      assert deleted_user.name == "Frank"

      # Verify user is deleted
      assert users.get(user.id) == nil
    end

    @tag relations: [:users]
    test "delete! accepts struct", %{users: users} do
      {:ok, user} = users.insert(%{name: "Grace", email: "grace@example.com"})

      deleted_user = users.delete!(user)

      assert deleted_user.id == user.id
      assert deleted_user.name == "Grace"

      # Verify user is deleted
      assert users.get(user.id) == nil
    end
  end

  describe "insert! function" do
    @tag relations: [:users]
    test "insert! accepts map", %{users: users} do
      user = users.insert!(%{name: "Henry", email: "henry@example.com"})

      assert user.name == "Henry"
      assert user.email == "henry@example.com"
      assert user.id != nil
    end

    @tag relations: [:users]
    test "insert! accepts changeset", %{users: users} do
      changeset = users.changeset(%{name: "Iris", email: "iris@example.com"})
      user = users.insert!(changeset)

      assert user.name == "Iris"
      assert user.email == "iris@example.com"
      assert user.id != nil
    end

    @tag relations: [:users]
    test "insert! accepts struct", %{users: users} do
      user_struct = users.struct(%{name: "Jack", email: "jack@example.com"})
      user = users.insert!(user_struct)

      assert user.name == "Jack"
      assert user.email == "jack@example.com"
      assert user.id != nil
    end
  end

  describe "reload functions" do
    @tag relations: [:users]
    test "reload returns updated struct", %{users: users} do
      {:ok, user} = users.insert(%{name: "Kate", email: "kate@example.com"})

      # Update the user directly in the database
      users.update(user, %{name: "Kate Updated"})

      # Reload the original struct
      reloaded_user = users.reload(user)
      assert reloaded_user.name == "Kate Updated"
      assert reloaded_user.id == user.id
    end

    @tag relations: [:users]
    test "reload! returns updated struct", %{users: users} do
      {:ok, user} = users.insert(%{name: "Liam", email: "liam@example.com"})

      # Update the user directly in the database
      users.update(user, %{name: "Liam Updated"})

      # Reload the original struct
      reloaded_user = users.reload!(user)
      assert reloaded_user.name == "Liam Updated"
      assert reloaded_user.id == user.id
    end
  end

  describe "insert_all function" do
    @tag relations: [:users]
    test "insert_all inserts multiple records", %{users: users} do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      entries = [
        %{name: "Mike", email: "mike@example.com", inserted_at: now, updated_at: now},
        %{name: "Nina", email: "nina@example.com", inserted_at: now, updated_at: now},
        %{name: "Oscar", email: "oscar@example.com", inserted_at: now, updated_at: now}
      ]

      {count, _} = users.insert_all(entries)
      assert count == 3

      # Verify all users were inserted
      all_users = users.all()
      names = Enum.map(all_users, & &1.name)
      assert "Mike" in names
      assert "Nina" in names
      assert "Oscar" in names
    end

    @tag relations: [:users]
    test "insert_all with empty list", %{users: users} do
      {count, _} = users.insert_all([])
      assert count == 0
    end
  end

  describe "struct function" do
    @tag relations: [:users]
    test "struct creates new struct with default attributes", %{users: users} do
      user_struct = users.struct()

      assert user_struct.__struct__ == users.__schema_module__()
      assert user_struct.id == nil
      assert user_struct.name == nil
      assert user_struct.email == nil
    end

    @tag relations: [:users]
    test "struct creates new struct with given attributes", %{users: users} do
      user_struct = users.struct(%{name: "Paul", email: "paul@example.com"})

      assert user_struct.__struct__ == users.__schema_module__()
      assert user_struct.name == "Paul"
      assert user_struct.email == "paul@example.com"
      assert user_struct.id == nil
    end
  end
end
