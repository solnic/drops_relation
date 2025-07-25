defmodule Mix.Tasks.Drops.Relation.InstallTest do
  use Test.IntegrationCase, async: false

  describe "installs drops_relation in pristine app" do
    @describetag app: "pristine", files: ["mix.exs"]

    test "creates aliases in mix.exs when none exist" do
      # Verify initial state - no aliases function
      initial_content = read_file("mix.exs")
      refute initial_content =~ "aliases"

      # Run the install task
      _output = run_task!("drops.relation.install --yes")

      # Verify the task ran successfully (Igniter may output different messages)
      # The important thing is that it doesn't error out

      # Verify aliases were added
      updated_content = read_file("mix.exs")
      assert updated_content =~ "def aliases do"

      assert updated_content =~
               ~s("ecto.migrate": ["ecto.migrate", "drops.relation.refresh_cache"])

      assert updated_content =~
               ~s("ecto.rollback": ["ecto.rollback", "drops.relation.refresh_cache"])

      assert updated_content =~ ~s("ecto.load": ["ecto.load", "drops.relation.refresh_cache"])
    end

    test "is idempotent - running multiple times doesn't duplicate aliases" do
      # Run install task twice
      run_task!("drops.relation.install --yes")
      run_task!("drops.relation.install --yes")

      # Verify aliases are not duplicated
      content = read_file("mix.exs")

      # Count occurrences of the refresh_cache task
      refresh_cache_count =
        content
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "drops.relation.refresh_cache"))

      # Should appear exactly 3 times (once for each alias)
      assert refresh_cache_count == 3
    end
  end

  describe "updates existing aliases in sample app" do
    @describetag app: "sample", files: ["mix.exs"]

    test "preserves existing aliases and adds refresh_cache task" do
      # Verify initial state - aliases already exist
      initial_content = read_file("mix.exs")
      assert initial_content =~ "aliases: aliases()"

      assert initial_content =~
               ~s("ecto.migrate": ["ecto.migrate", "drops.relation.refresh_cache"])

      # Run the install task
      _output = run_task!("drops.relation.install --yes")

      # Verify aliases are still correct and not duplicated
      updated_content = read_file("mix.exs")

      assert updated_content =~
               ~s("ecto.migrate": ["ecto.migrate", "drops.relation.refresh_cache"])

      assert updated_content =~
               ~s("ecto.rollback": ["ecto.rollback", "drops.relation.refresh_cache"])

      assert updated_content =~ ~s("ecto.load": ["ecto.load", "drops.relation.refresh_cache"])

      # Count occurrences to ensure no duplication
      refresh_cache_count =
        updated_content
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "drops.relation.refresh_cache"))

      # Should appear exactly 3 times (once for each alias)
      assert refresh_cache_count == 3
    end
  end
end
