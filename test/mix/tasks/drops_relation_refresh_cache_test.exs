defmodule Mix.Tasks.Drops.Relation.RefreshCacheTest do
  use Test.IntegrationCase, async: false

  describe "refresh_cache mix task integration" do
    test "shows help when --help is provided" do
      output = run_task!("drops.relation.refresh_cache --help")

      assert output =~ "Refreshes the Drops.Relation cache"
      assert output =~ "Usage"
      assert output =~ "--repo"
      assert output =~ "--all-repos"
      assert output =~ "--tables"
      assert output =~ "--verbose"
    end

    @tag adapter: :sqlite
    test "refreshes cache for specific repository with SQLite" do
      output = run_task!("drops.relation.refresh_cache --repo Sample.Repos.Sqlite --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Refreshing Drops.Relation cache"
      refute output =~ "Processing repository:"
      refute output =~ "Cache cleared for"
      refute output =~ "Successful:"
      refute output =~ "Failed:"
    end

    test "refreshes cache for default repository" do
      output = run_task!("drops.relation.refresh_cache --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Refreshing Drops.Relation cache"
      refute output =~ "Processing repository:"
      refute output =~ "Cache cleared for"
      refute output =~ "Successful:"
      refute output =~ "Failed:"
    end

    test "refreshes cache for specific tables only" do
      output =
        run_task!("drops.relation.refresh_cache --tables users,posts --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Refreshing Drops.Relation cache"
      refute output =~ "Tables:"
      refute output =~ "Processing repository:"
      refute output =~ "Cache cleared for"
    end

    test "handles invalid table names gracefully" do
      output =
        run_task!("drops.relation.refresh_cache --tables non_existent_table --verbose")

      # Should still succeed but may show warnings about non-existent tables
      assert output =~ "Cache refresh completed"
    end

    test "refreshes cache with all-repos option" do
      output = run_task!("drops.relation.refresh_cache --all-repos --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Refreshing Drops.Relation cache"
      refute output =~ "Successful:"
    end

    test "handles empty tables list" do
      output =
        run_task!("drops.relation.refresh_cache --tables '' --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Successful:"
    end

    test "provides concise output without verbose flag" do
      output = run_task!("drops.relation.refresh_cache")

      # Should not contain verbose details (these go to Logger anyway)
      refute output =~ "Processing repository:"
      refute output =~ "Cache cleared for"
      refute output =~ "Successful:"
      refute output =~ "Failed:"

      # But should contain summary
      assert output =~ "Cache refresh completed"
    end
  end

  describe "error handling" do
    test "uses default repositories when none specified" do
      # Since sample has ecto_repos configured, it should use those by default
      output = run_task!("drops.relation.refresh_cache --verbose")

      # Only the completion message should appear in terminal output
      assert output =~ "Cache refresh completed"
      # Verbose logging goes to Logger, not terminal output
      refute output =~ "Refreshing Drops.Relation cache"
      refute output =~ "Successful:"
    end

    test "handles non-existent repository gracefully" do
      {output, exit_code} = run_task("drops.relation.refresh_cache --repo NonExistent.Repo")

      assert exit_code != 0
      assert output =~ "could not be found" or output =~ "not found" or output =~ "error"
    end
  end
end
