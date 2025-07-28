defmodule Drops.Relation.Plugins.AutoRestrictTest do
  use Test.RelationCase, async: false

  describe "Doctests" do
    @describetag fixtures: [:users, :posts]

    doctest Drops.Relation.Plugins.AutoRestrict
  end

  describe "single column index finders" do
    @tag relations: [:users]
    test "get_by_email/1 works with unique index", %{users: users} do
      # Insert test data
      {:ok, user} = users.insert(%{name: "Test User", email: "test@example.com", active: true})

      # Test the auto-generated finder
      user_query = users.get_by_email("test@example.com")
      assert user_query != nil
      assert is_struct(user_query)

      # Execute the query
      found_user = users.one(user_query)
      assert found_user.id == user.id
      assert found_user.name == "Test User"
      assert found_user.email == "test@example.com"
    end

    @tag relations: [:users]
    test "get_by_name/1 works with non-unique index", %{users: users} do
      # Insert test data with same name
      {:ok, _user1} = users.insert(%{name: "John", email: "john1@example.com", active: true})
      {:ok, _user2} = users.insert(%{name: "John", email: "john2@example.com", active: false})

      # Test the auto-generated finder
      users_query = users.get_by_name("John")
      assert users_query != nil
      assert is_struct(users_query)

      # Execute the query
      found_users = users.all(users_query)
      assert length(found_users) == 2
      assert Enum.all?(found_users, &(&1.name == "John"))
    end
  end

  describe "composite index finders" do
    @tag relations: [:users]
    test "get_by_name_and_age/2 works with composite index", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "Alice", email: "alice@example.com", age: 25, active: true})

      {:ok, _user2} =
        users.insert(%{name: "Alice", email: "alice2@example.com", age: 30, active: true})

      {:ok, _user3} =
        users.insert(%{name: "Bob", email: "bob@example.com", age: 25, active: false})

      # Test the auto-generated composite finder
      user_query = users.get_by_name_and_age("Alice", 25)
      assert user_query != nil
      assert is_struct(user_query)

      # Execute the query
      found_user = users.one(user_query)
      assert found_user.name == "Alice"
      assert found_user.age == 25
      assert found_user.email == "alice@example.com"
    end
  end

  describe "composability with other operations" do
    @tag relations: [:users]
    test "auto-generated finders can be composed with restrict/2", %{users: users} do
      # Insert test data
      {:ok, _user1} = users.insert(%{name: "Charlie", email: "charlie@example.com", active: true})

      {:ok, _user2} =
        users.insert(%{name: "Charlie", email: "charlie2@example.com", active: false})

      # Test composing with restrict
      active_charlie =
        users.get_by_name("Charlie")
        |> users.restrict(active: true)
        |> users.one()

      assert active_charlie.name == "Charlie"
      assert active_charlie.active == true
      assert active_charlie.email == "charlie@example.com"
    end

    @tag relations: [:users]
    test "auto-generated finders can be composed with order/2", %{users: users} do
      # Insert test data
      {:ok, _user1} =
        users.insert(%{name: "David", email: "david1@example.com", age: 35, active: true})

      {:ok, _user2} =
        users.insert(%{name: "David", email: "david2@example.com", age: 25, active: true})

      # Test composing with order
      ordered_davids =
        users.get_by_name("David")
        |> users.order(:age)
        |> users.all()

      assert length(ordered_davids) == 2
      assert hd(ordered_davids).age == 25
      assert List.last(ordered_davids).age == 35
    end
  end

  describe "posts table finders" do
    @tag relations: [:posts, :users]
    test "get_by_user_id/1 works with foreign key index", %{posts: posts, users: users} do
      # Insert a user first
      {:ok, user} = users.insert(%{name: "Author", email: "author@example.com", active: true})

      # Insert posts for this user
      {:ok, _post1} =
        posts.insert(%{title: "First Post", body: "Content 1", user_id: user.id, published: true})

      {:ok, _post2} =
        posts.insert(%{
          title: "Second Post",
          body: "Content 2",
          user_id: user.id,
          published: false
        })

      # Test the auto-generated finder
      user_posts_query = posts.get_by_user_id(user.id)
      assert user_posts_query != nil
      assert is_struct(user_posts_query)

      # Execute the query
      user_posts = posts.all(user_posts_query)
      assert length(user_posts) == 2
      assert Enum.all?(user_posts, &(&1.user_id == user.id))
    end

    @tag relations: [:posts, :users]
    test "get_by_published/1 works with boolean index", %{posts: posts, users: users} do
      # Insert a user first
      {:ok, user} = users.insert(%{name: "Author", email: "author@example.com", active: true})

      # Insert posts with different published status
      {:ok, _post1} =
        posts.insert(%{
          title: "Published Post",
          body: "Content",
          user_id: user.id,
          published: true
        })

      {:ok, _post2} =
        posts.insert(%{title: "Draft Post", body: "Content", user_id: user.id, published: false})

      # Test finding published posts
      published_posts =
        posts.get_by_published(true)
        |> posts.all()

      assert length(published_posts) == 1
      assert hd(published_posts).title == "Published Post"
      assert hd(published_posts).published == true
    end
  end

  describe "chaining multiple operations" do
    @tag relations: [:posts, :users]
    test "complex query composition with auto-generated finders", %{posts: posts, users: users} do
      # Insert a user
      {:ok, user} = users.insert(%{name: "Blogger", email: "blogger@example.com", active: true})

      # Insert multiple posts
      {:ok, _post1} =
        posts.insert(%{
          title: "A Post",
          body: "Content",
          user_id: user.id,
          published: true,
          view_count: 100
        })

      {:ok, _post2} =
        posts.insert(%{
          title: "B Post",
          body: "Content",
          user_id: user.id,
          published: true,
          view_count: 50
        })

      {:ok, _post3} =
        posts.insert(%{
          title: "C Post",
          body: "Content",
          user_id: user.id,
          published: false,
          view_count: 10
        })

      # Test complex composition
      popular_published_posts =
        posts.get_by_user_id(user.id)
        |> posts.restrict(published: true)
        |> posts.order(desc: :view_count)
        |> posts.all()
        |> Enum.filter(&(&1.view_count > 75))

      assert length(popular_published_posts) == 1
      assert hd(popular_published_posts).title == "A Post"
      assert hd(popular_published_posts).view_count == 100
    end
  end
end
