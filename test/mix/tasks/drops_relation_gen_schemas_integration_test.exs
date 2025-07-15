defmodule Mix.Tasks.Drops.Relation.GenSchemasIntegrationTest do
  use ExUnit.Case, async: false

  @sample_app_path Path.join([__DIR__, "..", "..", "sample_app"])
  @schemas_path Path.join([@sample_app_path, "lib", "sample_app", "schemas"])

  setup do
    # Clean up any existing schema files before each test
    if File.exists?(@schemas_path) do
      File.rm_rf!(@schemas_path)
    end

    # Ensure the schemas directory exists
    File.mkdir_p!(@schemas_path)

    # Change to sample_app directory for mix tasks
    original_cwd = File.cwd!()
    File.cd!(@sample_app_path)

    # Set MIX_ENV to dev to avoid test database ownership issues
    original_env = System.get_env("MIX_ENV")
    System.put_env("MIX_ENV", "dev")

    on_exit(fn ->
      File.cd!(original_cwd)
      # Restore original MIX_ENV
      if original_env do
        System.put_env("MIX_ENV", original_env)
      else
        System.delete_env("MIX_ENV")
      end

      # Clean up after test
      if File.exists?(@schemas_path) do
        File.rm_rf!(@schemas_path)
      end
    end)

    :ok
  end

  describe "gen_schemas mix task integration" do
    test "generates schema files for all tables with --yes option" do
      # Run the mix task with --yes to avoid prompts using System.cmd to ensure proper environment
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "drops.relation.gen_schemas",
            "--app",
            "SampleApp",
            "--repo",
            "SampleApp.Repo",
            "--namespace",
            "SampleApp.Schemas",
            "--yes"
          ],
          env: [{"MIX_ENV", "dev"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "Mix task failed with output: #{output}"

      # Verify the task ran successfully
      assert output =~ "Creating or updating schema"
      assert output =~ "SampleApp.Schemas.Users"
      assert output =~ "SampleApp.Schemas.Posts"
      assert output =~ "SampleApp.Schemas.Comments"

      # Verify schema files were created
      user_file = Path.join(@schemas_path, "users.ex")
      post_file = Path.join(@schemas_path, "posts.ex")
      comment_file = Path.join(@schemas_path, "comments.ex")

      assert File.exists?(user_file)
      assert File.exists?(post_file)
      assert File.exists?(comment_file)

      # Verify user schema content
      user_content = File.read!(user_file)
      assert user_content =~ "defmodule SampleApp.Schemas.Users do"
      assert user_content =~ "use Ecto.Schema"
      assert user_content =~ "schema(\"users\") do"
      assert user_content =~ "field(:email, :string)"
      assert user_content =~ "field(:first_name, :string)"
      assert user_content =~ "field(:age, :integer)"
      assert user_content =~ "field(:is_active, :boolean"
      assert user_content =~ "timestamps()"

      # Verify post schema content with foreign key
      post_content = File.read!(post_file)
      assert post_content =~ "defmodule SampleApp.Schemas.Posts do"
      assert post_content =~ "use Ecto.Schema"
      assert post_content =~ "schema(\"posts\") do"
      assert post_content =~ "field(:title, :string)"
      assert post_content =~ "field(:body, :string)"
      assert post_content =~ "field(:user_id, :integer)"
      assert post_content =~ "timestamps()"

      # Verify comment schema content with multiple foreign keys
      comment_content = File.read!(comment_file)
      assert comment_content =~ "defmodule SampleApp.Schemas.Comments do"
      assert comment_content =~ "use Ecto.Schema"
      assert comment_content =~ "schema(\"comments\") do"
      assert comment_content =~ "field(:body, :string)"
      assert comment_content =~ "field(:user_id, :integer)"
      assert comment_content =~ "field(:post_id, :integer)"
      assert comment_content =~ "timestamps()"
    end

    test "generates schema for specific table only" do
      # Run the mix task for users table only
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "drops.relation.gen_schemas",
            "--app",
            "SampleApp",
            "--repo",
            "SampleApp.Repo",
            "--namespace",
            "SampleApp.Schemas",
            "--tables",
            "users",
            "--yes"
          ],
          env: [{"MIX_ENV", "dev"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "Mix task failed with output: #{output}"

      # Verify only user schema was created
      assert output =~ "SampleApp.Schemas.Users"
      refute output =~ "SampleApp.Schemas.Posts"
      refute output =~ "SampleApp.Schemas.Comments"

      user_file = Path.join(@schemas_path, "users.ex")
      post_file = Path.join(@schemas_path, "posts.ex")
      comment_file = Path.join(@schemas_path, "comments.ex")

      assert File.exists?(user_file)
      refute File.exists?(post_file)
      refute File.exists?(comment_file)
    end

    test "updates existing schema file in sync mode" do
      # First, create an initial schema file with custom content
      user_file = Path.join(@schemas_path, "users.ex")

      initial_content = """
      defmodule SampleApp.Schemas.Users do
        use Ecto.Schema

        schema "users" do
          field :email, :string
          field :first_name, :string
          # This is a custom comment that should be preserved
          timestamps()
        end

        # Custom function that should be preserved
        def display_name(%__MODULE__{first_name: first}) do
          "User: \#{first}"
        end
      end
      """

      File.write!(user_file, initial_content)

      # Run the mix task in sync mode
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "drops.relation.gen_schemas",
            "--app",
            "SampleApp",
            "--repo",
            "SampleApp.Repo",
            "--namespace",
            "SampleApp.Schemas",
            "--tables",
            "users",
            "--sync",
            "--yes"
          ],
          env: [{"MIX_ENV", "dev"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "Mix task failed with output: #{output}"

      # Verify the task ran in sync mode
      assert output =~ "Creating or updating schema"

      # Verify the file was updated
      updated_content = File.read!(user_file)

      # Should preserve custom function
      assert updated_content =~ "def display_name"

      # Should preserve custom comment
      assert updated_content =~ "This is a custom comment"

      assert updated_content =~ ~r/field\s*\(?:email,\s*:string\)?/
      assert updated_content =~ ~r/field\s*\(?:first_name,\s*:string\)?/
    end

    test "generated schemas are valid Ecto.Schema modules" do
      # Generate schemas
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "drops.relation.gen_schemas",
            "--app",
            "SampleApp",
            "--repo",
            "SampleApp.Repo",
            "--namespace",
            "SampleApp.Schemas",
            "--yes"
          ],
          env: [{"MIX_ENV", "dev"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "Mix task failed with output: #{output}"

      # Load and verify each generated schema module
      user_file = Path.join(@schemas_path, "users.ex")
      post_file = Path.join(@schemas_path, "posts.ex")
      comment_file = Path.join(@schemas_path, "comments.ex")

      # Compile and load the modules to verify they're valid
      [{user_module, _}] = Code.compile_file(user_file)
      [{post_module, _}] = Code.compile_file(post_file)
      [{comment_module, _}] = Code.compile_file(comment_file)

      # Verify they implement Ecto.Schema behavior
      assert function_exported?(user_module, :__schema__, 1)
      assert function_exported?(post_module, :__schema__, 1)
      assert function_exported?(comment_module, :__schema__, 1)

      # Verify schema metadata
      assert user_module.__schema__(:source) == "users"
      assert post_module.__schema__(:source) == "posts"
      assert comment_module.__schema__(:source) == "comments"

      # Verify fields exist
      user_fields = user_module.__schema__(:fields)
      assert :email in user_fields
      assert :first_name in user_fields
      assert :last_name in user_fields
      assert :age in user_fields

      post_fields = post_module.__schema__(:fields)
      assert :title in post_fields
      assert :body in post_fields
      assert :user_id in post_fields

      comment_fields = comment_module.__schema__(:fields)
      assert :body in comment_fields
      assert :user_id in comment_fields
      assert :post_id in comment_fields
    end
  end
end
