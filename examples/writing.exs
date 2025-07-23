defmodule Users do
  use Drops.Relation, repo: Test.Repos.Postgres

  schema("users", infer: true)
end

Enum.each(Users.all(), &Users.delete/1)

# Simple insert with a map
{:ok, user} = Users.insert(%{name: "John", active: false})

# Simple update with a struct
{:ok, user} = Users.get!(user.id) |> Users.update(%{name: "John", active: true})

IO.inspect(user)
