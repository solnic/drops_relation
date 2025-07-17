defmodule Users do
  use Drops.Relation, repo: SampleApp.Repo

  schema("users", infer: true)

  view(:active) do
    schema([:id, :email, :active])

    derive do
      restrict(active: true)
    end
  end
end
