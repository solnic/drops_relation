defmodule Drops.Relation.Compilers.SchemaCompiler do
  @moduledoc false

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey, ForeignKey, Index}
  alias Drops.SQL.Database

  @doc """
  Dispatches to the appropriate database-specific schema compiler based on the table's adapter.

  This function provides backward compatibility by automatically selecting the correct
  database-specific compiler based on the table's adapter field.

  ## Parameters

  - `table` - A Drops.SQL.Database.Table struct with adapter information
  - `opts` - Optional compilation options

  ## Returns

  A Drops.Relation.Schema.t() struct.

  ## Examples

      iex> {:ok, table} = Database.table("users", MyApp.Repo)
      iex> schema = SchemaCompiler.visit(table, %{})
      iex> %Drops.Relation.Schema{} = schema
  """
  @spec visit(Database.Table.t(), map()) :: Schema.t()
  def visit(%Database.Table{adapter: adapter} = table, opts) do
    case adapter do
      :postgres ->
        Drops.Relation.Compilers.PostgresSchemaCompiler.process(table, opts)

      :sqlite ->
        Drops.Relation.Compilers.SqliteSchemaCompiler.process(table, opts)

      _ ->
        raise ArgumentError, "Unsupported database adapter: #{inspect(adapter)}"
    end
  end

  @doc """
  Macro for implementing database schema compiler modules.

  This macro sets up the necessary aliases and compilation hooks to generate
  visitor functions for processing database component structs.

  ## Options

  Any options passed to the macro are stored and made available via the
  generated `opts/0` function.

  ## Generated Functions

  - `opts/0` - Returns the compiler options
  - `process/2` - Main entry point for database component processing
  - `visit/2` - Visitor functions for different database component types

  ## Example

      defmodule MySchemaCompiler do
        use Drops.Relation.Compilers.SchemaCompiler, some_option: :value

        # Implement adapter-specific type conversion
        def visit(%Database.Column{} = column, opts) do
          # Custom column processing
        end
      end
  """
  defmacro __using__(opts) do
    quote location: :keep do
      alias Drops.Relation.Schema
      alias Drops.Relation.Schema.{Field, PrimaryKey, ForeignKey, Index}
      alias Drops.SQL.Database

      @before_compile unquote(__MODULE__)
      @opts unquote(opts)
    end
  end

  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :opts)

    quote location: :keep do
      # Returns the compiler configuration options.
      @spec opts() :: keyword()
      def opts, do: @opts

      # Main entry point for processing database components.
      # Merges provided options with compiler defaults and delegates to visitor pattern.
      @spec process(Database.Table.t(), map()) :: Schema.t()
      def process(table, opts) do
        visit(table, Map.merge(opts, Map.new(unquote(opts))))
      end

      # Define components mapping at module level
      @components [{:name, :source}, {:columns, :fields}, :primary_key, :foreign_keys, :indices]

      # Visits a table struct and constructs a Schema struct.
      # Processes table components and creates a complete Schema struct.
      @spec visit(Database.Table.t(), map()) :: Schema.t()
      def visit(%Database.Table{} = table, opts) do
        attributes =
          Enum.reduce(@components, %{}, fn spec, acc ->
            [source_key, target_key] =
              case spec do
                {source, target} -> [source, target]
                name -> [name, name]
              end

            new_opts = Map.merge(opts, acc)
            component = visit(Map.get(table, source_key), Map.put(new_opts, :table, table))
            Map.put(acc, target_key, component)
          end)

        Schema.new(attributes)
      end

      @spec visit(Database.Column.t(), map()) :: Field.t()
      def visit(%Database.Column{} = column, _opts) do
        components = [:name, :type, :meta]

        result =
          Enum.reduce(components, %{}, fn key, acc ->
            Map.put(acc, key, visit({key, Map.get(column, key)}, column.meta))
          end)

        {type, meta} =
          case result.type do
            {value, %{} = info} ->
              {value, Map.merge(result.meta, info)}

            value ->
              {value, result.meta}
          end

        Field.new(result.name, type, Map.put(meta, :type, column.type))
      end

      def visit({:meta, meta}, opts) do
        Enum.reduce(meta, %{}, fn {key, _} = tuple, acc ->
          Map.put(acc, key, visit(tuple, opts))
        end)
      end

      # Visits a primary key struct and constructs a PrimaryKey struct.
      @spec visit(Database.PrimaryKey.t(), map()) :: PrimaryKey.t()
      def visit(%Database.PrimaryKey{columns: columns} = primary_key, %{fields: fields}) do
        names = Enum.map(columns, & &1.name)
        fields = Enum.filter(fields, &(&1.name in names))

        PrimaryKey.new(fields)
      end

      # Visits a foreign key struct and constructs a ForeignKey struct.
      @spec visit(Database.ForeignKey.t(), map()) :: ForeignKey.t()
      def visit(%Database.ForeignKey{} = foreign_key, _opts) do
        field_name = List.first(foreign_key.columns)
        referenced_field = List.first(foreign_key.referenced_columns)

        ForeignKey.new(field_name, foreign_key.referenced_table, referenced_field)
      end

      # Visits an index struct and constructs an Index struct.
      @spec visit(Database.Index.t(), map()) :: Index.t()
      def visit(%Database.Index{} = index, %{fields: fields}) do
        fields = Enum.filter(fields, &(&1.name in index.columns))

        Index.new(index.name, fields, index.meta.unique, index.meta.type)
      end

      # Visits a list of components and processes each one.
      @spec visit(list(), map()) :: list()
      def visit(node, opts) when is_list(node) do
        Enum.map(node, &visit(&1, opts))
      end

      # Catch-all for nodes
      @spec visit({atom(), term()}, map()) :: term()
      def visit({type, value}, _opts), do: value

      # Visits any other value and returns it as-is.
      @spec visit(term(), map()) :: term()
      def visit(value, _opts), do: value
    end
  end
end
