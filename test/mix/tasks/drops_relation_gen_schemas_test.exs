defmodule Mix.Tasks.Drops.Relation.GenSchemasTest do
  use Drops.RelationCase, async: false

  alias Drops.Relation.Schema.Generator

  describe "GenSchemas fix verification" do
    test "generated schema content has no duplicated defmodule statements" do
      # Test the Generator directly to verify the fix for the duplicated defmodule issue
      field = Drops.Relation.Schema.Field.new(:name, :string, %{source: :name})
      schema = Drops.Relation.Schema.new("users", nil, [], [field], [])

      # Generate schema content as string (this is what the task does)
      ast = Generator.generate_module_content("TestApp.Relations.User", "users", schema)
      schema_content = Macro.to_string(ast)

      # Verify there's only one defmodule statement (the main fix)
      defmodule_count =
        schema_content
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "defmodule"))

      assert defmodule_count == 1,
             "Expected exactly 1 defmodule, got #{defmodule_count}. Content:\n#{schema_content}"

      # Verify the content structure is correct
      assert schema_content =~ "defmodule TestApp.Relations.User do"
      assert schema_content =~ "use Ecto.Schema"
      assert schema_content =~ "schema(\"users\")"
      assert schema_content =~ "field(:name, :string)"
      assert schema_content =~ "timestamps()"

      # Most importantly: verify it doesn't contain nested defmodule
      refute schema_content =~ ~r/defmodule.*defmodule/s, "Found nested defmodule statements"

      # Verify the generated content is valid Elixir code
      assert {_result, _bindings} = Code.eval_quoted(ast)
    end

    test "generated schema with complex fields has no duplicated defmodule" do
      # Test with more complex schema to ensure the fix works in all cases
      fields = [
        Drops.Relation.Schema.Field.new(:id, :id, %{source: :id, primary_key: true}),
        Drops.Relation.Schema.Field.new(:email, :string, %{source: :email}),
        Drops.Relation.Schema.Field.new(:age, :integer, %{source: :age}),
        Drops.Relation.Schema.Field.new(:active, :boolean, %{source: :active, default: true})
      ]

      pk = Drops.Relation.Schema.PrimaryKey.new([List.first(fields)])
      schema = Drops.Relation.Schema.new("users", pk, [], fields, [])

      # Generate schema content
      ast = Generator.generate_module_content("TestApp.Relations.ComplexUser", "users", schema)
      schema_content = Macro.to_string(ast)

      # Verify single defmodule
      defmodule_count =
        schema_content
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "defmodule"))

      assert defmodule_count == 1, "Expected exactly 1 defmodule, got #{defmodule_count}"

      # Verify no nested defmodule
      refute schema_content =~ ~r/defmodule.*defmodule/s, "Found nested defmodule statements"

      # Verify it compiles
      assert {_result, _bindings} = Code.eval_quoted(ast)
    end
  end
end
