defmodule Drops.Relation.LoadCacheTest do
  use ExUnit.Case, async: false

  alias Drops.Relation.Cache

  setup do
    Cache.clear_all()
    Test.Repos.start_all(:manual)
    :ok
  end

  describe "load_cache/1" do
    test "loads cache for all tables in repository" do
      Test.Repos.with_owner(Test.Repos.Postgres, fn repo ->
        assert Cache.get_cached_schema(repo, "users") == nil

        assert Drops.Relation.load_cache(repo) == :ok

        cached_schema = Cache.get_cached_schema(repo, "users")
        assert cached_schema != nil
        assert cached_schema.source == :users
      end)
    end

    test "loads cache for SQLite repository" do
      Test.Repos.with_owner(Test.Repos.Sqlite, fn repo ->
        assert Cache.get_cached_schema(repo, "users") == nil
        assert Drops.Relation.load_cache(repo) == :ok

        cached_schema = Cache.get_cached_schema(repo, "users")
        assert cached_schema != nil
        assert cached_schema.source == :users
      end)
    end

    test "returns ok when no tables exist in database" do
      Test.Repos.with_owner(Test.Repos.Sqlite, fn repo ->
        result = Drops.Relation.load_cache(repo)
        assert result == :ok
      end)
    end

    test "returns error when repository has invalid adapter" do
      defmodule InvalidRepo do
        def config, do: [adapter: :invalid_adapter]
        def __adapter__, do: :invalid_adapter
      end

      assert {:error, {:unsupported_adapter, :invalid_adapter}} =
               Drops.Relation.load_cache(InvalidRepo)
    end
  end
end
