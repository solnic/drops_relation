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
      assert output =~ "--warm-up"
      assert output =~ "--verbose"
    end

    test "refreshes cache for specific repository" do
      output = run_task!("drops.relation.refresh_cache --repo SampleApp.Repo --verbose")

      assert output =~ "Refreshing Drops.Relation cache"
      assert output =~ "Processing repository: SampleApp.Repo"
      assert output =~ "Cache cleared for SampleApp.Repo"
      assert output =~ "Cache warmed up for"
      assert output =~ "Cache refresh completed"
      assert output =~ "Successful: 1"
      assert output =~ "Failed: 0"
    end

    test "refreshes cache for specific tables only" do
      output =
        run_task!(
          "drops.relation.refresh_cache --repo SampleApp.Repo --tables users,posts --verbose"
        )

      assert output =~ "Refreshing Drops.Relation cache"
      assert output =~ "Tables: [\"users\", \"posts\"]"
      assert output =~ "Processing repository: SampleApp.Repo"
      assert output =~ "Cache cleared for SampleApp.Repo"
      assert output =~ "Cache warmed up for 2 tables"
      assert output =~ "Cache refresh completed"
    end

    test "clears cache without warming up when warm-up is false" do
      output =
        run_task!("drops.relation.refresh_cache --repo SampleApp.Repo --no-warm-up --verbose")

      assert output =~ "Warm up: false"
      assert output =~ "Cache cleared (warm-up skipped)"
      assert output =~ "cleared (0 tables)"
    end

    test "handles invalid table names gracefully" do
      output =
        run_task!(
          "drops.relation.refresh_cache --repo SampleApp.Repo --tables non_existent_table --verbose"
        )

      # Should still succeed but may show warnings about non-existent tables
      assert output =~ "Cache refresh completed"
    end

    test "refreshes cache with all-repos option" do
      output = run_task!("drops.relation.refresh_cache --all-repos --verbose")

      assert output =~ "Refreshing Drops.Relation cache"
      assert output =~ "Cache refresh completed"
      # Should process at least SampleApp.Repo
      assert output =~ "Successful:"
    end

    test "handles empty tables list" do
      output =
        run_task!("drops.relation.refresh_cache --repo SampleApp.Repo --tables '' --verbose")

      assert output =~ "Cache refresh completed"
      assert output =~ "Successful: 1"
    end

    test "provides concise output without verbose flag" do
      output = run_task!("drops.relation.refresh_cache --repo SampleApp.Repo")

      # Should not contain verbose details
      refute output =~ "Processing repository:"
      refute output =~ "Cache cleared for"
      refute output =~ "Detailed results:"

      # But should contain summary
      assert output =~ "Cache refresh completed"
    end
  end

  describe "error handling" do
    test "uses default repositories when none specified" do
      # Since sample_app has ecto_repos configured, it should use those by default
      output = run_task!("drops.relation.refresh_cache --verbose")

      assert output =~ "Refreshing Drops.Relation cache"
      assert output =~ "Cache refresh completed"
      assert output =~ "Successful:"
    end

    test "handles non-existent repository gracefully" do
      {output, exit_code} = run_task("drops.relation.refresh_cache --repo NonExistent.Repo")

      assert exit_code != 0
      assert output =~ "could not be found" or output =~ "not found" or output =~ "error"
    end
  end
end
