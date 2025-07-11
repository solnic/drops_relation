defmodule Drops.Relation.Schema.GeneratorTest do
  use Drops.RelationCase, async: false

  alias Drops.Relation.Schema.Generator
  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey}

  # Helper function to compile a schema module from Generator output
  defp compile_test_schema(schema, module_name, table_name) do
    ast = Generator.generate_module_content(module_name, table_name, schema)
    {_result, _bindings} = Code.eval_quoted(ast)
    String.to_existing_atom(module_name)
  end

  # Helper function to generate a unique module name for each test
  defp generate_module_name(base_name) do
    timestamp = System.system_time(:nanosecond)
    "#{base_name}#{timestamp}"
  end

  describe "Generator.generate_schema_module/3" do
    test "generates working Ecto schema module for simple table" do
      # Create a simple schema
      field = Field.new(:name, :string, %{source: :name})
      schema = Schema.new("users", nil, [], [field], [])

      # Compile the module using helper
      module = compile_test_schema(schema, "TestModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :name in module.__schema__(:fields)
      assert module.__schema__(:type, :name) == :string
    end

    test "generates working schema with UUID primary key" do
      field = Field.new(:id, Ecto.UUID, %{source: :id, primary_key: true})
      pk = PrimaryKey.new([field])
      schema = Schema.new("users", pk, [], [field], [])

      module = compile_test_schema(schema, "TestUUIDModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert module.__schema__(:primary_key) == [:id]
      assert module.__schema__(:type, :id) == Ecto.UUID
    end

    test "generates working schema with binary_id primary key" do
      field = Field.new(:uuid, :binary_id, %{source: :uuid, primary_key: true})
      pk = PrimaryKey.new([field])
      schema = Schema.new("users", pk, [], [field], [])

      module = compile_test_schema(schema, "TestBinaryIdModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert module.__schema__(:primary_key) == [:uuid]
      assert module.__schema__(:type, :uuid) == :binary_id
    end

    test "generates working schema with composite primary keys" do
      field1 = Field.new(:user_id, :integer, %{source: :user_id, primary_key: true})
      field2 = Field.new(:role_id, :integer, %{source: :role_id, primary_key: true})
      pk = PrimaryKey.new([field1, field2])
      schema = Schema.new("user_roles", pk, [], [field1, field2], [])

      module = compile_test_schema(schema, "TestCompositeModule", "user_roles")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "user_roles"
      assert module.__schema__(:primary_key) == [:user_id, :role_id]
      assert module.__schema__(:type, :user_id) == :integer
      assert module.__schema__(:type, :role_id) == :integer
    end

    test "generates working schema with default values" do
      field = Field.new(:status, :string, %{source: :status, default: "active"})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, "TestDefaultModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :status in module.__schema__(:fields)
      assert module.__schema__(:type, :status) == :string

      # Verify default value by creating a struct
      struct = struct(module)
      assert struct.status == "active"
    end

    test "generates working schema with Ecto.Enum fields" do
      field = Field.new(:status, {Ecto.Enum, [values: [:active, :inactive]]}, %{source: :status})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, "TestEnumModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :status in module.__schema__(:fields)
      # Ecto.Enum types are returned as parameterized types
      assert {:parameterized, {Ecto.Enum, _}} = module.__schema__(:type, :status)

      # Verify the enum works by creating a changeset
      changeset = Ecto.Changeset.cast(struct(module), %{status: :active}, [:status])
      assert changeset.valid?
    end

    test "generates working schema with source mapping" do
      field = Field.new(:email, :string, %{source: :email_address})
      schema = Schema.new("users", nil, [], [field], [])

      module = compile_test_schema(schema, "TestSourceModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :email in module.__schema__(:fields)
      assert module.__schema__(:type, :email) == :string
      # Note: Ecto doesn't expose source mapping through reflection,
      # but the fact that it compiles without error validates the AST
    end

    test "skips timestamp fields" do
      field1 = Field.new(:name, :string, %{source: :name})
      field2 = Field.new(:inserted_at, :naive_datetime, %{source: :inserted_at})
      field3 = Field.new(:updated_at, :naive_datetime, %{source: :updated_at})
      schema = Schema.new("users", nil, [], [field1, field2, field3], [])

      module = compile_test_schema(schema, "TestTimestampModule", "users")

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :name in module.__schema__(:fields)

      # Timestamp fields should be handled by timestamps() macro, not individual field definitions
      # They should still be in the schema fields because timestamps() adds them
      assert :inserted_at in module.__schema__(:fields)
      assert :updated_at in module.__schema__(:fields)
    end

    test "handles empty schema" do
      schema = Schema.new("empty", nil, [], [], [])

      module = compile_test_schema(schema, "TestEmptyModule", "empty")

      # Should compile successfully - Ecto automatically adds :id field when no primary key is specified
      assert module.__schema__(:source) == "empty"
      assert :id in module.__schema__(:fields)
      assert module.__schema__(:primary_key) == [:id]
    end
  end

  describe "Generator.generate_schema_module_string/3" do
    test "generates string representation of schema module" do
      field = Field.new(:name, :string, %{source: :name})
      schema = Schema.new("users", nil, [], [field], [])

      # We can't easily test the full function without a real repo,
      # but we can test the string conversion
      ast = Generator.generate_module_content("TestStringModule", "users", schema)
      string_result = Macro.to_string(ast)

      assert is_binary(string_result)
      assert string_result =~ "defmodule :TestStringModule"
      assert string_result =~ "use Ecto.Schema"
      assert string_result =~ "schema(\"users\")"
      assert string_result =~ "field(:name, :string)"
      assert string_result =~ "timestamps()"

      # Verify there's only one defmodule declaration
      defmodule_count = string_result |> String.split("defmodule") |> length() |> Kernel.-(1)
      assert defmodule_count == 1
    end
  end

  describe "Generator.sync_schema_content/3" do
    test "syncs existing schema content" do
      existing_content = """
      defmodule MyApp.User do
        use Ecto.Schema

        schema "users" do
          field :old_field, :string
          timestamps()
        end
      end
      """

      field = Field.new(:name, :string, %{source: :name})
      schema = Schema.new("users", nil, [], [field], [])

      result = Generator.sync_schema_content(existing_content, "users", schema)

      assert is_binary(result)
      assert result =~ "defmodule MyApp.User"
      assert result =~ "use Ecto.Schema"
      assert result =~ "schema(\"users\")"
      assert result =~ "field(:name, :string)"
      assert result =~ "timestamps()"
    end

    test "handles content without valid module name" do
      invalid_content = "not a valid module"
      field = Field.new(:name, :string, %{source: :name})
      schema = Schema.new("users", nil, [], [field], [])

      result = Generator.sync_schema_content(invalid_content, "users", schema)

      # Should return the original content as fallback
      assert result == invalid_content
    end
  end

  describe "Generator.extract_module_name/1" do
    test "extracts module name from valid content" do
      content = """
      defmodule MyApp.User do
        use Ecto.Schema
      end
      """

      result = Generator.extract_module_name(content)
      assert result == "MyApp.User"
    end

    test "returns nil for invalid content" do
      content = "not a valid module"
      result = Generator.extract_module_name(content)
      assert result == nil
    end
  end

  describe "Generator with real database introspection" do
    @tag relations: [:users], adapter: :sqlite
    test "generates working schema from real users table", %{users: _users} do
      # Use the Generator to introspect and generate schema for the users table
      options = %{repo: "Drops.Relation.Repos.Sqlite"}
      module_name = generate_module_name("GeneratedUserSchema")

      ast = Generator.generate_schema_module("users", module_name, options)
      {_result, _bindings} = Code.eval_quoted(ast)
      module = String.to_existing_atom(module_name)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :id in module.__schema__(:fields)
      assert :name in module.__schema__(:fields)
      assert :email in module.__schema__(:fields)
      assert :age in module.__schema__(:fields)

      # Check field types
      assert module.__schema__(:type, :id) == :id
      assert module.__schema__(:type, :name) == :string
      assert module.__schema__(:type, :email) == :string
      assert module.__schema__(:type, :age) == :integer

      # Check primary key
      assert module.__schema__(:primary_key) == [:id]
    end

    @tag relations: [:uuid_organizations], adapter: :sqlite
    test "generates working schema from real UUID table", %{uuid_organizations: _orgs} do
      options = %{repo: "Drops.Relation.Repos.Sqlite"}
      module_name = generate_module_name("GeneratedOrgSchema")

      ast = Generator.generate_schema_module("uuid_organizations", module_name, options)
      {_result, _bindings} = Code.eval_quoted(ast)
      module = String.to_existing_atom(module_name)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "uuid_organizations"
      assert :id in module.__schema__(:fields)
      assert :name in module.__schema__(:fields)

      # Check field types - UUID primary key should be binary_id
      assert module.__schema__(:type, :id) == :binary_id
      assert module.__schema__(:type, :name) == :string

      # Check primary key
      assert module.__schema__(:primary_key) == [:id]
    end

    @tag relations: [:composite_pk], adapter: :sqlite
    test "generates working schema from real composite primary key table", %{
      composite_pk: _composite
    } do
      options = %{repo: "Drops.Relation.Repos.Sqlite"}
      module_name = generate_module_name("GeneratedCompositeSchema")

      ast = Generator.generate_schema_module("composite_pk", module_name, options)
      {_result, _bindings} = Code.eval_quoted(ast)
      module = String.to_existing_atom(module_name)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "composite_pk"
      assert :part1 in module.__schema__(:fields)
      assert :part2 in module.__schema__(:fields)
      assert :data in module.__schema__(:fields)

      # Check field types
      assert module.__schema__(:type, :part1) == :string
      # Note: SQLite may report integer primary key fields as :id type
      assert module.__schema__(:type, :part2) in [:integer, :id]
      assert module.__schema__(:type, :data) == :string

      # Check composite primary key
      assert module.__schema__(:primary_key) == [:part1, :part2]
    end

    @tag relations: [:users], adapter: :postgres
    test "generates working schema from PostgreSQL users table", %{users: _users} do
      options = %{repo: "Drops.Relation.Repos.Postgres"}
      module_name = generate_module_name("GeneratedPostgresUserSchema")

      ast = Generator.generate_schema_module("users", module_name, options)
      {_result, _bindings} = Code.eval_quoted(ast)
      module = String.to_existing_atom(module_name)

      # Verify the schema was compiled correctly
      assert module.__schema__(:source) == "users"
      assert :id in module.__schema__(:fields)
      assert :name in module.__schema__(:fields)
      assert :email in module.__schema__(:fields)

      # Check field types
      assert module.__schema__(:type, :id) == :id
      assert module.__schema__(:type, :name) == :string
      assert module.__schema__(:type, :email) == :string

      # Check primary key
      assert module.__schema__(:primary_key) == [:id]
    end
  end
end
