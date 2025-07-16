defmodule Users do
  use Drops.Relation, repo: Drops.Relation.Repos.Postgres, name: "users"

  view(:active) do
    schema([:id, :name, :active])

    relation do
      restrict(active: true)
    end
  end
end

Users.insert(%{name: "John", active: false})
Users.insert(%{name: "Jane", active: true})
Users.insert(%{name: "Joe", active: false})
Users.insert(%{name: "Jade", active: true})
