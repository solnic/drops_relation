defmodule Drops.Relation.ConfigurablePluginsTest do
  use ExUnit.Case, async: false

  describe "plugin configuration" do
    test "default plugins function returns expected list" do
      default_plugins = Drops.Relation.Config.default_plugins(nil)

      expected_plugins = [
        Drops.Relation.Plugins.Schema,
        Drops.Relation.Plugins.Reading,
        Drops.Relation.Plugins.Writing,
        Drops.Relation.Plugins.Loadable,
        Drops.Relation.Plugins.Views,
        Drops.Relation.Plugins.Queryable,
        Drops.Relation.Plugins.AutoRestrict,
        Drops.Relation.Plugins.Pagination,
        Drops.Relation.Plugins.Ecto.Query
      ]

      assert default_plugins == expected_plugins
    end

    test "can specify custom plugins list in opts" do
      opts = [plugins: [Drops.Relation.Plugins.Schema, Drops.Relation.Plugins.Reading]]

      assert opts[:plugins] == [Drops.Relation.Plugins.Schema, Drops.Relation.Plugins.Reading]
    end

    test "empty plugins list is supported" do
      opts = [plugins: []]

      assert opts[:plugins] == []
    end
  end

  describe "config-based default plugins" do
    test "can configure default plugins via application config" do
      config_schema =
        Drops.Relation.Config.validate!(
          default_plugins: [
            Drops.Relation.Plugins.Schema,
            Drops.Relation.Plugins.Reading
          ]
        )

      assert config_schema[:default_plugins] == [
               Drops.Relation.Plugins.Schema,
               Drops.Relation.Plugins.Reading
             ]
    end
  end

  describe "function-based default plugins config" do
    test "can configure default plugins via function" do
      plugins_fn = fn _relation ->
        [Drops.Relation.Plugins.Schema, Drops.Relation.Plugins.Writing]
      end

      config_schema = Drops.Relation.Config.validate!(default_plugins: plugins_fn)

      assert is_function(config_schema[:default_plugins], 1)
    end
  end

  describe "integration test" do
    test "plugins option is properly passed through to relation definition" do
      opts_with_plugins = [
        repo: Test.Repos.Sqlite,
        name: "users",
        plugins: [Drops.Relation.Plugins.Schema]
      ]

      assert opts_with_plugins[:plugins] == [Drops.Relation.Plugins.Schema]

      opts_without_plugins = [
        repo: Test.Repos.Sqlite,
        name: "users"
      ]

      assert opts_without_plugins[:plugins] == nil
    end
  end
end
