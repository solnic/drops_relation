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

  ## Examples

  ### Single Column Index Finders

      iex> # Find user by email (unique index)
      iex> user_query = MyApp.Users.get_by_email("john@example.com")
      iex> user = MyApp.Users.one(user_query)
      iex> user.name
      "John Doe"
      iex> user.email
      "john@example.com"

      iex> # Find users by name (non-unique index)
      iex> users_query = MyApp.Users.get_by_name("Jane Smith")
      iex> users = MyApp.Users.all(users_query)
      iex> length(users)
      1
      iex> hd(users).name
      "Jane Smith"

  ### Composite Index Finders

      iex> # Find by composite index (name + age)
      iex> user_query = MyApp.Users.get_by_name_and_age("John Doe", 30)
      iex> user = MyApp.Users.one(user_query)
      iex> user.name
      "John Doe"
      iex> user.age
      30

  ### Composable with Other Operations

      iex> # Chain with restrictions
      iex> active_user = MyApp.Users.get_by_email("john@example.com")
      ...>   |> MyApp.Users.restrict(active: true)
      ...>   |> MyApp.Users.one()
      iex> active_user.name
      "John Doe"
      iex> active_user.active
      true

      iex> # Chain with ordering
      iex> ordered_users = MyApp.Users.get_by_name("John Doe")
      ...>   |> MyApp.Users.order(:age)
      ...>   |> MyApp.Users.all()
      iex> length(ordered_users)
      1
      iex> hd(ordered_users).age
      30

  ### Blog Posts Example

      iex> # Find posts by user (foreign key index)
      iex> user_posts = MyApp.Posts.get_by_user_id(1)
      ...>   |> MyApp.Posts.restrict(published: true)
      ...>   |> MyApp.Posts.order(desc: :view_count)
      ...>   |> MyApp.Posts.all()
      iex> length(user_posts)
      1
      iex> hd(user_posts).title
      "First Post"
      iex> hd(user_posts).published
      true

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
