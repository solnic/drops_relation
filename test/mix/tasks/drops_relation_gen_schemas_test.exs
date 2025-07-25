defmodule Mix.Tasks.Drops.Relation.GenSchemasTest do
  use Test.IntegrationCase, async: false

  describe "gen_schemas mix task integration" do
    @describetag clean_dirs: ["lib/sample_app/schemas"]

    test "generates schema files for all tables with --yes option" do
      # Run the mix task with --yes to avoid prompts
      output =
        run_task!(
          "drops.relation.gen_schemas --app Sample --repo Sample.Repo --namespace Sample.Schemas --yes"
        )

      # Verify the task ran successfully
      assert output =~ "Creating or updating schema"
      assert output =~ "Sample.Schemas.Users"
      assert output =~ "Sample.Schemas.Posts"
      assert output =~ "Sample.Schemas.Comments"

      # Verify schema files were created
      assert_file_exists("lib/sample_app/schemas/users.ex")
      assert_file_exists("lib/sample_app/schemas/posts.ex")
      assert_file_exists("lib/sample_app/schemas/comments.ex")

      # Verify user schema content
      user_content = read_file("lib/sample_app/schemas/users.ex")
      assert user_content =~ "defmodule Sample.Schemas.Users do"
      assert user_content =~ "use Ecto.Schema"
      assert user_content =~ "schema(\"users\") do"
      assert user_content =~ "field(:email, :string)"
      assert user_content =~ "field(:first_name, :string)"
      assert user_content =~ "field(:age, :integer)"
      assert user_content =~ "field(:active, :boolean"
      assert user_content =~ "timestamps()"

      # Verify post schema content with foreign key
      post_content = read_file("lib/sample_app/schemas/posts.ex")
      assert post_content =~ "defmodule Sample.Schemas.Posts do"
      assert post_content =~ "use Ecto.Schema"
      assert post_content =~ "schema(\"posts\") do"
      assert post_content =~ "field(:title, :string)"
      assert post_content =~ "field(:body, :string)"
      assert post_content =~ "field(:user_id, :integer)"
      assert post_content =~ "timestamps()"

      # Verify comment schema content with multiple foreign keys
      comment_content = read_file("lib/sample_app/schemas/comments.ex")
      assert comment_content =~ "defmodule Sample.Schemas.Comments do"
      assert comment_content =~ "use Ecto.Schema"
      assert comment_content =~ "schema(\"comments\") do"
      assert comment_content =~ "field(:body, :string)"
      assert comment_content =~ "field(:user_id, :integer)"
      assert comment_content =~ "field(:post_id, :integer)"
      assert comment_content =~ "timestamps()"
    end

    test "generates schema for specific table only" do
      # Run the mix task for users table only
      output =
        run_task!(
          "drops.relation.gen_schemas --app Sample --repo Sample.Repo --namespace Sample.Schemas --tables users --yes"
        )

      # Verify only user schema was created
      assert output =~ "Sample.Schemas.Users"
      refute output =~ "Sample.Schemas.Posts"
      refute output =~ "Sample.Schemas.Comments"

      assert_file_exists("lib/sample_app/schemas/users.ex")
      refute_file_exists("lib/sample_app/schemas/posts.ex")
      refute_file_exists("lib/sample_app/schemas/comments.ex")
    end

    test "updates existing schema file in sync mode" do
      # First, create an initial schema file with custom content
      initial_content = """
      defmodule Sample.Schemas.Users do
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

      write_file("lib/sample_app/schemas/users.ex", initial_content)

      # Run the mix task in sync mode
      output =
        run_task!(
          "drops.relation.gen_schemas --app Sample --repo Sample.Repo --namespace Sample.Schemas --tables users --sync --yes"
        )

      # Verify the task ran in sync mode
      assert output =~ "Creating or updating schema"

      # Verify the file was updated
      updated_content = read_file("lib/sample_app/schemas/users.ex")

      # Should preserve custom function
      assert updated_content =~ "def display_name"

      # Should preserve custom comment
      assert updated_content =~ "This is a custom comment"

      assert updated_content =~ ~r/field\s*\(?:email,\s*:string\)?/
      assert updated_content =~ ~r/field\s*\(?:first_name,\s*:string\)?/
    end

    test "generated schemas are valid Ecto.Schema modules" do
      run_task!(
        "drops.relation.gen_schemas --app Sample --repo Sample.Repo --namespace Sample.Schemas --yes"
      )

      # Load and verify each generated schema module
      user_file = Path.expand("lib/sample_app/schemas/users.ex")
      post_file = Path.expand("lib/sample_app/schemas/posts.ex")
      comment_file = Path.expand("lib/sample_app/schemas/comments.ex")

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
