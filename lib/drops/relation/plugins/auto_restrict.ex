defmodule Drops.Relation.Plugins.AutoRestrict do
  @moduledoc """
  Plugin that automatically generates finder functions based on database indices.

  This plugin analyzes the relation's schema indices and generates composable
  finder functions like `get_by_email/1`, `get_by_name/1`, etc. These functions
  are automatically available on any relation module that includes this plugin.

  ## Generated Functions

  For each database index, this plugin generates corresponding finder functions:

  - Single column index on `email` → `get_by_email/1`
  - Single column index on `name` → `get_by_name/1`
  - Composite index on `email, role` → `get_by_email_and_role/2`
  - Composite index on `user_id, status` → `get_by_user_id_and_status/2`

  ## Usage Examples

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)
      end

      # Assuming users table has an index on email column
      users_query = MyApp.Users.get_by_email("john@example.com")  # Returns relation
      user = MyApp.Users.one(users_query)                        # Execute query

      # Composable with other operations
      active_user = MyApp.Users
                    |> MyApp.Users.get_by_email("john@example.com")
                    |> MyApp.Users.restrict(active: true)
                    |> MyApp.Users.one()

      # Works with composite indices too
      # Assuming index on (email, role) columns
      admin_user = MyApp.Users.get_by_email_and_role("john@example.com", "admin")
                   |> MyApp.Users.one()

      # Chain with ordering and other operations
      recent_posts = MyApp.Posts
                     |> MyApp.Posts.get_by_author_id(user.id)
                     |> MyApp.Posts.restrict(published: true)
                     |> MyApp.Posts.order(desc: :created_at)
                     |> MyApp.Posts.all()

  ## Function Behavior

  All generated functions return relation structs that can be:
  - Executed with `one/1`, `all/1`, etc.
  - Composed with `restrict/2`, `order/2`, `preload/2`
  - Used with `Enum` functions for further processing

  The functions are named using the pattern `get_by_<column>` for single columns
  and `get_by_<column1>_and_<column2>` for composite indices.
  """

  alias Drops.Relation.Plugins.AutoRestrict.SchemaCompiler

  use Drops.Relation.Plugin

  def on(:before_compile, _relation, %{schema: schema}) do
    functions = SchemaCompiler.visit(schema, %{})

    quote do
      (unquote_splicing(functions))
    end
  end
end
