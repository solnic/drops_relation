defmodule Drops.Relation.Plugins.AutoRestrict do
  @moduledoc """
  Plugin that automatically generates finder functions based on database indices.

  This plugin analyzes the relation's schema indices and generates composable
  finder functions like `get_by_email/1`, `get_by_name/1`, etc.

  ## Examples

      # If users table has an index on email
      users = Users.get_by_email("john@example.com")  # Returns relation
      user = users |> Users.one()                     # Execute query

      # Composable with other operations
      active_user = Users
                    |> Users.get_by_email("john@example.com")
                    |> Users.restrict(active: true)
                    |> Users.one()

      # Works with composite indices too
      user = Users.get_by_email_and_role("john@example.com", "admin")
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
