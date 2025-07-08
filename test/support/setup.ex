Code.require_file("repos.ex", __DIR__)

Code.require_file("ecto/test_schemas.ex", __DIR__)
Code.require_file("ecto/user_group_schemas.ex", __DIR__)

Application.ensure_all_started(:ecto_relation)
