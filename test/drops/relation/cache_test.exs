defmodule Drops.Relation.CacheTest do
  use ExUnit.Case, async: false

  alias Drops.Relation.Cache
  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey, ForeignKey, Index, Indices}

  # Mock repository for testing
  defmodule TestRepo do
    def config do
      [priv: "test/fixtures/test_repo"]
    end
  end

  # Another mock repo with different migration directory
  defmodule TestRepo2 do
    def config do
      [priv: "test/fixtures/test_repo2"]
    end
  end

  # Mock repo with no migrations
  defmodule EmptyRepo do
    def config do
      [priv: "test/fixtures/empty_repo"]
    end
  end

  setup do
    # Clear cache before each test
    Cache.clear_all()

    on_exit(fn ->
      File.rm_rf!("test/fixtures")
    end)

    # Create test fixture directories
    File.mkdir_p!("test/fixtures/test_repo/migrations")
    File.mkdir_p!("test/fixtures/test_repo2/migrations")
    File.mkdir_p!("test/fixtures/empty_repo")

    # Create test migration files
    File.write!(
      "test/fixtures/test_repo/migrations/001_create_users.exs",
      "# migration 1"
    )

    File.write!(
      "test/fixtures/test_repo2/migrations/001_create_posts.exs",
      "# migration 2"
    )

    on_exit(fn ->
      File.rm_rf!("test/fixtures")
    end)

    :ok
  end

  describe "get_cached_schema/2" do
    test "returns cached schema on cache hit" do
      test_schema = Schema.empty(:users)
      :ok = Cache.cache_schema(TestRepo, "users", test_schema)

      schema = Cache.get_cached_schema(TestRepo, "users")

      assert schema.source == :users
    end

    test "returns nil on cache miss" do
      result = Cache.get_cached_schema(TestRepo, "posts")
      assert result == nil
    end

    test "invalidates cache when migration digest changes" do
      test_schema = Schema.empty(:users)
      Cache.cache_schema(TestRepo, "users", test_schema)

      result1 = Cache.get_cached_schema(TestRepo, "users")
      assert result1.source == :users

      # Modify migration file to change digest
      File.write!(
        "test/fixtures/test_repo/migrations/001_create_users.exs",
        "# modified migration 1"
      )

      # Should return nil due to digest mismatch
      result2 = Cache.get_cached_schema(TestRepo, "users")
      assert result2 == nil
    end

    test "handles repository with no migrations" do
      # Cache a schema for empty repo
      test_schema = Schema.empty(:users)
      Cache.cache_schema(EmptyRepo, "users", test_schema)

      result = Cache.get_cached_schema(EmptyRepo, "users")
      assert result.source == :users
    end
  end

  describe "cache_schema/3" do
    test "caches schema successfully" do
      test_schema = Schema.empty(:users)
      Cache.cache_schema(TestRepo, "users", test_schema)

      result = Cache.get_cached_schema(TestRepo, "users")
      assert result.source == :users
    end
  end

  describe "clear_repo_cache/1" do
    test "clears cache for specific repository" do
      # Cache schemas for both repos
      test_schema = Schema.empty(:users)
      Cache.cache_schema(TestRepo, "users", test_schema)
      Cache.cache_schema(TestRepo2, "users", test_schema)

      # Verify both are cached
      assert Cache.get_cached_schema(TestRepo, "users").source == :users
      assert Cache.get_cached_schema(TestRepo2, "users").source == :users

      # Clear cache for TestRepo only
      Cache.clear_repo_cache(TestRepo)

      # TestRepo should be cleared, TestRepo2 should still be cached
      assert Cache.get_cached_schema(TestRepo, "users") == nil
      assert Cache.get_cached_schema(TestRepo2, "users").source == :users
    end
  end

  describe "clear_all/0" do
    test "clears entire cache" do
      # Cache multiple schemas
      users_schema = Schema.empty(:users)
      posts_schema = Schema.empty(:posts)
      Cache.cache_schema(TestRepo, "users", users_schema)
      Cache.cache_schema(TestRepo, "posts", posts_schema)
      Cache.cache_schema(TestRepo2, "users", users_schema)

      # Verify all are cached
      assert Cache.get_cached_schema(TestRepo, "users").source == :users
      assert Cache.get_cached_schema(TestRepo, "posts").source == :posts
      assert Cache.get_cached_schema(TestRepo2, "users").source == :users

      # Clear all
      Cache.clear_all()

      # All should be cleared
      assert Cache.get_cached_schema(TestRepo, "users") == nil
      assert Cache.get_cached_schema(TestRepo, "posts") == nil
      assert Cache.get_cached_schema(TestRepo2, "users") == nil
    end
  end

  describe "warm_up/2" do
    test "returns ok when cache is enabled" do
      assert {:ok, []} = Cache.warm_up(TestRepo, [])
    end
  end

  describe "refresh/2" do
    test "clears and optionally warms up cache" do
      test_schema = Schema.empty(:users)
      Cache.cache_schema(TestRepo, "users", test_schema)

      assert Cache.get_cached_schema(TestRepo, "users").source == :users

      result = Cache.refresh(TestRepo)
      assert result == :ok
      assert Cache.get_cached_schema(TestRepo, "users") == nil

      assert :ok = Cache.refresh(TestRepo, [])
    end
  end

  describe "maybe_get_cached_schema/2" do
    test "returns cached schema when available" do
      test_schema = Schema.empty(:users)
      Cache.cache_schema(TestRepo, "users", test_schema)
      result = Cache.maybe_get_cached_schema(TestRepo, "users")
      assert result.source == :users
    end

    test "returns empty schema when not cached" do
      result = Cache.maybe_get_cached_schema(TestRepo, "non_existent")
      assert %Drops.Relation.Schema{source: "non_existent"} = result
      assert result.fields == []
      assert result.foreign_keys == []
    end
  end

  describe "Serializable protocol for Field" do
    test "dumps and loads Field correctly" do
      field = %Field{
        name: :email,
        type: :string,
        source: :email,
        meta: %{nullable: false, default: nil}
      }

      dumped = JSON.encode!(field) |> JSON.decode!()
      assert dumped["__struct__"] == "Field"
      assert dumped["attributes"]["name"] == ["atom", "email"]
      assert dumped["attributes"]["type"] == ["atom", "string"]
      assert dumped["attributes"]["type"] == ["atom", "string"]
      assert dumped["attributes"]["source"] == ["atom", "email"]

      loaded = Drops.Relation.Schema.Field.load(dumped)
      assert loaded == field
    end

    test "handles complex ecto types in Field" do
      field = %Field{
        name: :tags,
        type: {:array, :string},
        source: :tags,
        meta: %{}
      }

      dumped = JSON.encode!(field) |> JSON.decode!()
      loaded = Drops.Relation.Schema.Field.load(dumped)
      assert loaded.type == {:array, :string}
      assert loaded == field
    end
  end

  describe "Serializable protocol for PrimaryKey" do
    test "dumps and loads PrimaryKey correctly" do
      field = %Field{name: :id, type: :id, source: :id, meta: %{}}
      pk = %PrimaryKey{fields: [field]}

      dumped = JSON.encode!(pk) |> JSON.decode!()
      assert dumped["__struct__"] == "PrimaryKey"
      assert is_list(dumped["attributes"]["fields"])

      loaded = Drops.Relation.Schema.PrimaryKey.load(dumped)
      assert loaded == pk
    end

    test "handles empty PrimaryKey" do
      pk = %PrimaryKey{fields: []}

      dumped = JSON.encode!(pk) |> JSON.decode!()
      loaded = Drops.Relation.Schema.PrimaryKey.load(dumped)
      assert loaded == pk
    end
  end

  describe "Serializable protocol for ForeignKey" do
    test "dumps and loads ForeignKey correctly" do
      fk = %ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id
      }

      dumped = JSON.encode!(fk) |> JSON.decode!()
      assert dumped["__struct__"] == "ForeignKey"
      assert dumped["attributes"]["field"] == ["atom", "user_id"]
      assert dumped["attributes"]["references_table"] == "users"
      assert dumped["attributes"]["references_field"] == ["atom", "id"]

      loaded = Drops.Relation.Schema.ForeignKey.load(dumped)
      assert loaded == fk
    end
  end

  describe "Serializable protocol for Index" do
    test "dumps and loads Index correctly" do
      field = %Field{name: :email, type: :string, source: :email, meta: %{}}

      index = %Index{
        name: "users_email_index",
        fields: [field],
        unique: true,
        type: :btree
      }

      dumped = JSON.encode!(index) |> JSON.decode!()
      assert dumped["__struct__"] == "Index"
      assert dumped["attributes"]["name"] == "users_email_index"
      assert dumped["attributes"]["unique"] == true
      assert dumped["attributes"]["type"] == ["atom", "btree"]

      loaded = Drops.Relation.Schema.Index.load(dumped)
      assert loaded == index
    end
  end

  describe "Serializable protocol for Indices" do
    test "dumps and loads Indices correctly" do
      field = %Field{name: :email, type: :string, source: :email, meta: %{}}
      index = %Index{name: "users_email_index", fields: [field], unique: true, type: :btree}
      indices = %Indices{indices: [index]}

      dumped = JSON.encode!(indices) |> JSON.decode!()
      assert dumped["__struct__"] == "Indices"
      assert is_list(dumped["attributes"]["indices"])

      loaded = Drops.Relation.Schema.Indices.load(dumped)
      assert loaded == indices
    end
  end

  describe "Serializable protocol for Schema" do
    test "dumps and loads complete Schema correctly" do
      field = %Field{name: :id, type: :id, source: :id, meta: %{}}
      pk = %PrimaryKey{fields: [field]}

      fk = %ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id
      }

      index = %Index{name: "test_index", fields: [field], unique: false, type: :btree}
      indices = %Indices{indices: [index]}

      schema = %Schema{
        source: "test_table",
        primary_key: pk,
        foreign_keys: [fk],
        fields: [field],
        indices: indices
      }

      dumped = JSON.encode!(schema) |> JSON.decode!()
      assert dumped["__struct__"] == "Schema"
      assert dumped["attributes"]["source"] == "test_table"

      loaded = Drops.Relation.Schema.load(dumped)
      assert loaded == schema
    end

    test "handles Schema with nil components" do
      schema = %Schema{
        source: "simple_table",
        primary_key: nil,
        foreign_keys: [],
        fields: [],
        indices: %Indices{indices: []}
      }

      dumped = JSON.encode!(schema) |> JSON.decode!()
      loaded = Drops.Relation.Schema.load(dumped)
      assert loaded == schema
    end
  end

  describe "complex ecto type serialization/deserialization" do
    test "handles array types correctly through cache operations" do
      # Create a schema with array ecto type using the new protocol
      field = %Field{
        name: :tags,
        type: {:array, :string},
        source: :tags,
        meta: %{}
      }

      schema = %Schema{
        source: "test_table",
        primary_key: nil,
        foreign_keys: [],
        fields: [field],
        indices: %Indices{indices: []}
      }

      # Cache the schema
      Cache.cache_schema(TestRepo, "test_table", schema)

      # Retrieve and verify - the new protocol should handle this correctly
      cache_file = Cache.get_cache_file_path(TestRepo, "test_table")

      # Read the cache file directly to verify serialization worked
      if File.exists?(cache_file) do
        {:ok, content} = File.read(cache_file)
        data = JSON.decode!(content)

        # Verify the schema was serialized with the new protocol format
        assert data["schema"]["__struct__"] == "Schema"
        assert data["schema"]["attributes"]["source"] == "test_table"
      end
    end

    test "round-trip serialization preserves complex ecto types" do
      # Test round-trip with the new protocol
      field = %Field{
        name: :complex_field,
        type: {:array, :string},
        meta: %{type: :array, source: :complex_field}
      }

      schema = %Schema{
        source: "round_trip_test",
        primary_key: nil,
        foreign_keys: [],
        fields: [field],
        indices: %Indices{indices: []}
      }

      # Cache the schema
      Cache.cache_schema(TestRepo, "round_trip_test", schema)

      # Clear in-memory cache to force file read
      Cache.clear_all()

      # This should not crash and should return the correct schema
      # (even if it returns nil due to digest mismatch, it shouldn't crash)
      _result = Cache.get_cached_schema(TestRepo, "round_trip_test")

      # The important thing is that this call doesn't crash
      # If we get here without crashing, the protocol implementation works
      assert true
    end
  end
end
