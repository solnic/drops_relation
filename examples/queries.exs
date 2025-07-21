defmodule Users do
  use Drops.Relation, repo: Drops.Relation.Repos.Postgres

  schema("users", infer: true)

  defquery active() do
    from(u in relation(), where: u.active == true)
  end

  defquery by_name(names) when is_list(names) do
    from(u in relation(), where: u.name in ^names)
  end

  defquery by_name(name) when is_binary(name) do
    from(u in relation(), where: u.name in ^name)
  end

  defquery order(field) do
    from(u in relation(), order_by: [^field])
  end
end

Enum.each(Users.all(), &Users.delete/1)

Users.insert(%{name: "John", active: true})
Users.insert(%{name: "Jane", active: true})
Users.insert(%{name: "Joe", active: false})
Users.insert(%{name: "Jade", active: true})

users =
  Users.active()
  |> Users.by_name(["Jane", "John"])
  |> Users.order(:name)
  |> Enum.to_list()

IO.inspect(users)
# [
#   %Users.User{
#     __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
#     id: 26,
#     name: "Jane",
#     email: nil,
#     age: nil,
#     active: true,
#     inserted_at: ~N[2025-07-21 08:36:25],
#     updated_at: ~N[2025-07-21 08:36:25]
#   },
#   %Users.User{
#     __meta__: #Ecto.Schema.Metadata<:loaded, "users">,
#     id: 25,
#     name: "John",
#     email: nil,
#     age: nil,
#     active: true,
#     inserted_at: ~N[2025-07-21 08:36:25],
#     updated_at: ~N[2025-07-21 08:36:25]
#   }
# ]
