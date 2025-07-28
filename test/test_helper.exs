Code.require_file("support/test.ex", __DIR__)
Code.require_file("support/doctest_case.ex", __DIR__)
Code.require_file("support/relation_case.ex", __DIR__)
Code.require_file("support/integration_case.ex", __DIR__)

# Doctest setup
Code.require_file("support/doctest/my_app.ex", __DIR__)
Code.require_file("support/fixtures.ex", __DIR__)

Application.put_env(:my_app, :ecto_repos, [MyApp.Repo])
Application.put_env(:my_app, :drops, relation: [repo: MyApp.Repo])

Application.put_env(:my_app, MyApp.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  hostname: "postgres",
  database: "drops_relation_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/repo/postgres"
)

Drops.Relation.Cache.clear_all()

Test.Repos.with_owner(MyApp.Repo, fn repo ->
  {:ok, _} = Drops.Relation.Cache.warm_up(repo, ["users", "posts"])
end)

defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app

  schema("users", infer: true)
end

defmodule MyApp.Posts do
  use Drops.Relation, otp_app: :my_app

  schema("posts", infer: true)
end

ExUnit.start()
