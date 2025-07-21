defmodule Drops.Relations.Plugins.WritingTest do
  use Drops.RelationCase, async: false

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
end
