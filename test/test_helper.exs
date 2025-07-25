Code.require_file("support/doctest_case.ex", __DIR__)
Code.require_file("support/relation_case.ex", __DIR__)
Code.require_file("support/integration_case.ex", __DIR__)

Drops.Relation.Cache.clear_all()

ExUnit.start()
