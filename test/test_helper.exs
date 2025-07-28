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
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/repo/postgres",
  log: :debug
)

Drops.Relation.Cache.clear_all()

ExUnit.start()
