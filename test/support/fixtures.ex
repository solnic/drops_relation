defmodule Test.Fixtures do
  @moduledoc false

  @doc """
  Loads fixture data for the specified tables.

  ## Examples

      Test.Fixtures.load(:users)
      Test.Fixtures.load([:users, :posts])
  """
  def load(table_names) when is_list(table_names) do
    Enum.each(table_names, &load/1)
  end

  def load(table_name) when is_atom(table_name) do
    case table_name do
      :users -> load_users()
      :posts -> load_posts()
      _ -> raise ArgumentError, "Unknown fixture table: #{table_name}"
    end
  end

  @doc """
  Loads user fixtures into the users table.

  Creates 3 users with predictable data:
  - User with ID 1: "John Doe", "john@example.com", age 30, active: true
  - User with ID 2: "Jane Smith", "jane@example.com", age 25, active: true
  - User with ID 3: "Bob Wilson", "bob@example.com", age 35, active: false
  """
  def load_users do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    users = [
      %{
        id: 1,
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        active: true,
        settings: %{},
        inserted_at: now,
        updated_at: now
      },
      %{
        id: 2,
        name: "Jane Smith",
        email: "jane@example.com",
        age: 25,
        active: true,
        settings: %{},
        inserted_at: now,
        updated_at: now
      },
      %{
        id: 3,
        name: "Bob Wilson",
        email: "bob@example.com",
        age: 35,
        active: false,
        settings: %{},
        inserted_at: now,
        updated_at: now
      }
    ]

    MyApp.Repo.delete_all(MyApp.Users)
    MyApp.Repo.insert_all("users", users)

    reset_sequence("users", "id", 4)
  end

  def load_posts do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    posts = [
      %{
        id: 1,
        title: "First Post",
        body: "This is the first post content.",
        user_id: 1,
        published: true,
        view_count: 100,
        inserted_at: now,
        updated_at: now
      },
      %{
        id: 2,
        title: "Second Post",
        body: "This is the second post content.",
        user_id: 2,
        published: true,
        view_count: 50,
        inserted_at: now,
        updated_at: now
      },
      %{
        id: 3,
        title: "Draft Post",
        body: "This is a draft post.",
        user_id: 1,
        published: false,
        view_count: 0,
        inserted_at: now,
        updated_at: now
      },
      %{
        id: 4,
        title: "Another Post",
        body: "This is another post.",
        user_id: 3,
        published: true,
        view_count: 25,
        inserted_at: now,
        updated_at: now
      }
    ]

    MyApp.Repo.delete_all(MyApp.Posts)
    MyApp.Repo.insert_all("posts", posts)

    reset_sequence("posts", "id", 5)
  end

  defp reset_sequence(table_name, column_name, next_value) do
    sequence_name = "#{table_name}_#{column_name}_seq"
    MyApp.Repo.query!("SELECT setval('#{sequence_name}', #{next_value})")
  end
end
