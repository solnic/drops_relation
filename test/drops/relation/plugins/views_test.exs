defmodule Drops.Relation.Plugins.ViewsTest do
  use Test.RelationCase, async: false

  describe "Doctests" do
    @describetag fixtures: [:users, :posts]

    doctest Drops.Relation.Plugins.Views
  end

  describe "basic view functionality" do
    relation(:users) do
      schema("users", infer: true)

      view(:active) do
        schema([:id, :name, :active])

        derive do
          restrict(active: true)
        end
      end
    end

    test "view returns filtered and projected data", %{users: users} do
      # Insert test data
      users.insert(%{name: "John", email: "john@example.com", active: true})
      users.insert(%{name: "Jane", email: "jane@example.com", active: false})
      users.insert(%{name: "Bob", email: "bob@example.com", active: true})

      # Test the view
      active_users = users.active().all()

      assert length(active_users) == 2
      assert Enum.all?(active_users, & &1.active)
      assert Enum.all?(active_users, &(not Map.has_key?(&1, :email)))

      # Verify struct type
      assert hd(active_users).__struct__ == Test.Relations.Users.Active.Active
    end
  end

  describe "view with custom struct name" do
    relation(:users) do
      schema("users", infer: true)

      view(:public_profile) do
        schema([:id, :name, :active], struct: "PublicUser")

        derive do
          restrict(active: true)
        end
      end
    end

    test "view with custom struct name", %{users: users} do
      # Insert test data
      users.insert(%{name: "John", email: "john@example.com", active: true})
      users.insert(%{name: "Jane", email: "jane@example.com", active: false})

      # Test the view
      public_users = users.public_profile().all()

      assert length(public_users) == 1
      assert hd(public_users).__struct__ == Test.Relations.Users.PublicProfile.PublicUser
      assert hd(public_users).name == "John"
      assert not Map.has_key?(hd(public_users), :email)
      assert hd(public_users).active == true
    end
  end

  describe "multiple views on same relation" do
    relation(:posts) do
      schema("posts", infer: true)

      view(:popular) do
        schema([:id, :title, :view_count, :published])

        derive do
          restrict(published: true)
          |> order(desc: :view_count)
        end
      end

      view(:drafts) do
        schema([:id, :title, :user_id, :published])

        derive do
          restrict(published: false)
        end
      end
    end

    relation(:users) do
      schema("users", infer: true)
    end

    test "different views provide different perspectives", %{posts: posts, users: users} do
      # Insert users first to satisfy foreign key constraints
      {:ok, user1} = users.insert(%{name: "User 1", email: "user1@example.com", active: true})
      {:ok, user2} = users.insert(%{name: "User 2", email: "user2@example.com", active: true})

      # Insert test data
      posts.insert(%{
        title: "Popular Post",
        body: "Content",
        published: true,
        view_count: 100,
        user_id: user1.id
      })

      posts.insert(%{
        title: "Draft Post",
        body: "Draft content",
        published: false,
        view_count: 0,
        user_id: user1.id
      })

      posts.insert(%{
        title: "Unpopular Post",
        body: "Content",
        published: true,
        view_count: 5,
        user_id: user2.id
      })

      # Test popular view
      popular_posts = posts.popular().all()
      assert length(popular_posts) == 2
      assert hd(popular_posts).title == "Popular Post"
      assert hd(popular_posts).view_count == 100
      assert not Map.has_key?(hd(popular_posts), :body)

      # Test drafts view
      draft_posts = posts.drafts().all()
      assert length(draft_posts) == 1
      assert hd(draft_posts).title == "Draft Post"
      assert hd(draft_posts).published == false
      assert not Map.has_key?(hd(draft_posts), :view_count)
    end
  end

  describe "view chaining with other operations" do
    relation(:users) do
      schema("users", infer: true)

      view(:active) do
        schema([:id, :name, :age, :active])

        derive do
          restrict(active: true)
        end
      end
    end

    test "views can be further restricted and ordered", %{users: users} do
      # Insert test data
      users.insert(%{name: "Alice", email: "alice@example.com", active: true, age: 25})
      users.insert(%{name: "Bob", email: "bob@example.com", active: true, age: 30})
      users.insert(%{name: "Charlie", email: "charlie@example.com", active: false, age: 35})

      # Test chaining additional operations on the view
      alice_active_users =
        users.active()
        |> users.restrict(name: "Alice")
        |> users.order(:name)
        |> users.all()

      assert length(alice_active_users) == 1
      assert hd(alice_active_users).name == "Alice"
      assert hd(alice_active_users).age == 25
      assert hd(alice_active_users).active
    end
  end
end
