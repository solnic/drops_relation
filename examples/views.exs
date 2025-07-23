defmodule Users do
  use Drops.Relation, repo: Test.Repos.Postgres

  schema("users", infer: true)

  view(:active) do
    schema([:id, :name, :active])

    derive do
      restrict(active: true)
    end
  end
end

Enum.each(Users.all(), &Users.delete/1)

Users.insert(%{name: "John", active: false})
Users.insert(%{name: "Jane", active: true})
Users.insert(%{name: "Joe", active: false})
Users.insert(%{name: "Jade", active: true})

IO.inspect(Users.last())
# %Users.Schemas.User{
#   __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
#   id: 4,
#   name: "Jade",
#   email: nil,
#   age: nil,
#   active: true,
#   inserted_at: ~N[2025-07-16 21:56:47],
#   updated_at: ~N[2025-07-16 21:56:47]
# }

IO.inspect(Users.active() |> Enum.to_list())
# [
#   %Users.Schemas.Active{
#     __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
#     id: 2,
#     name: "Jane",
#     active: true
#   },
#   %Users.Schemas.Active{
#     __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
#     id: 4,
#     name: "Jade",
#     active: true
#   }
# ]
