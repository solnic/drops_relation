defmodule Users do
  use Drops.Relation, repo: Test.Repos.Postgres

  schema("users", infer: true)
end

Enum.each(Users.all(), &Users.delete/1)

{:ok, user} = Users.insert(%{name: "John", active: true})

Users.insert(%{name: "Jane", active: true})
Users.insert(%{name: "Joe", active: false})
Users.insert(%{name: "Jade", active: true})

# Common functions known from Ecto.Repo
Users.get(user.id)
Users.get!(user.id)

Users.get_by(name: "Jane")
Users.get_by!(name: "Jane")

Users.all()
Users.all_by(active: true)

# Additional functions for covenience
Users.first()
Users.last()
Users.count()

# Composable `restrict` function
Users.restrict(name: "Jane") |> Users.restrict(active: true)

# Composable `order` function
Users.restrict(active: true) |> Users.order(:name)
