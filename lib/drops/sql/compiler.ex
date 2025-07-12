defmodule Drops.SQL.Compiler do
  @moduledoc """
  Compiler behavior and macro for processing database introspection ASTs.

  This module provides a macro-based compiler framework that transforms database
  introspection ASTs into structured `Drops.SQL.Database.*` structs. It implements
  a visitor pattern where each AST node type is processed by a corresponding
  `visit/2` function.

  ## Architecture

  The compiler uses a macro-based approach to generate visitor functions that
  process different types of AST nodes. Each database adapter has its own
  compiler module that uses this macro and implements adapter-specific type
  conversions and processing logic.

  ## Visitor Pattern

  The generated `visit/2` functions follow a consistent pattern:

  - `visit({:table, components}, opts)` - Processes table AST nodes
  - `visit({:column, components}, opts)` - Processes column AST nodes
  - `visit({:foreign_key, components}, opts)` - Processes foreign key AST nodes
  - `visit({:index, components}, opts)` - Processes index AST nodes
  - `visit({:identifier, name}, opts)` - Processes identifier nodes
  - `visit({:type, type}, opts)` - Processes type nodes (adapter-specific)
  - `visit({:meta, meta}, opts)` - Processes metadata nodes

  ## Generated Functions

  When a module uses this compiler, the following functions are generated:

  - `opts/0` - Returns the compiler options
  - `process/2` - Main entry point for processing AST nodes
  - `visit/2` - Visitor functions for different AST node types

  ## Usage

      defmodule MyCompiler do
        use Drops.SQL.Compiler

        # Implement adapter-specific type conversion
        def visit({:type, "varchar"}, _opts), do: :string
        def visit({:type, "integer"}, _opts), do: :integer
        # ... other type mappings
      end

      # Process a table AST
      ast = {:table, {{:identifier, "users"}, columns, foreign_keys, indices}}
      table = MyCompiler.process(ast, adapter: :my_adapter)

  ## Implementing Compilers

  To create a new compiler:

  1. Use the `Drops.SQL.Compiler` macro
  2. Implement `visit({:type, type}, opts)` for your database's type system
  3. Optionally override other visitor functions for custom behavior
  4. Optionally implement `visit({:default, value}, opts)` for default value processing

  ## AST Structure

  The compiler expects AST nodes in the following format:

      # Table
      {:table, {name, columns, foreign_keys, indices}}

      # Column
      {:column, {name, type, meta}}

      # Foreign Key
      {:foreign_key, {name, columns, referenced_table, referenced_columns, meta}}

      # Index
      {:index, {name, columns, meta}}

      # Identifier
      {:identifier, string_name}

      # Type (adapter-specific)
      {:type, type_value}

      # Metadata
      {:meta, metadata_map}
  """

  alias Drops.SQL.Database.{Table, Column, PrimaryKey, ForeignKey, Index}

  @doc """
  Macro for implementing database compiler modules.

  This macro sets up the necessary aliases and compilation hooks to generate
  visitor functions for processing database AST nodes.

  ## Options

  Any options passed to the macro are stored and made available via the
  generated `opts/0` function.

  ## Generated Functions

  - `opts/0` - Returns the compiler options
  - `process/2` - Main entry point for AST processing
  - `visit/2` - Visitor functions for different AST node types

  ## Example

      defmodule MyCompiler do
        use Drops.SQL.Compiler, some_option: :value

        # Implement adapter-specific type mappings
        def visit({:type, "text"}, _opts), do: :string
      end
  """
  defmacro __using__(opts) do
    quote location: :keep do
      alias Drops.SQL.Database.{Table, Column, PrimaryKey, ForeignKey, Index}

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

      # Main entry point for processing database AST nodes.
      # Merges provided options with compiler defaults and delegates to visitor pattern.
      @spec process(tuple(), map()) :: Table.t() | term()
      def process(node, opts) do
        visit(node, Map.merge(opts, Map.new(unquote(opts))))
      end

      # Visits a table AST node and constructs a Table struct.
      # Processes table components and creates a complete Table struct with inferred primary key.
      @spec visit({:table, list()}, map()) :: Table.t()
      def visit({:table, components}, opts) do
        [name, columns, foreign_keys, indices] = visit(components, opts)

        primary_key = PrimaryKey.from_columns(columns)

        Table.new(name, opts[:adapter], columns, primary_key, foreign_keys, indices)
      end

      # Visits an identifier AST node and converts it to an atom.
      @spec visit({:identifier, String.t()}, map()) :: atom()
      def visit({:identifier, name}, _opts), do: String.to_atom(name)

      # Visits a column AST node and constructs a Column struct.
      @spec visit({:column, list()}, map()) :: Column.t()
      def visit({:column, components}, opts) do
        [name, type, meta] = visit(components, opts)
        Column.new(name, type, meta)
      end

      # Visits a type AST node. Default implementation returns type as-is.
      # Adapter-specific compilers should override this for type mapping.
      @spec visit({:type, term()}, map()) :: term()
      def visit({:type, type}, _opts), do: type

      # Visits a metadata AST node and processes nested values recursively.
      @spec visit({:meta, map()}, map()) :: map()
      def visit({:meta, meta}, opts) when is_map(meta) do
        Enum.reduce(meta, %{}, fn {key, value}, acc ->
          Map.put(acc, key, visit(value, opts))
        end)
      end

      # Visits an index AST node and constructs an Index struct.
      @spec visit({:index, list()}, map()) :: Index.t()
      def visit({:index, components}, opts) do
        [name, columns, meta] = visit(components, opts)
        Index.new(name, columns, meta)
      end

      # Visits a foreign key AST node and constructs a ForeignKey struct.
      @spec visit({:foreign_key, list()}, map()) :: ForeignKey.t()
      def visit({:foreign_key, components}, opts) do
        [name, columns, referenced_table, referenced_columns, meta] = visit(components, opts)
        ForeignKey.new(name, columns, referenced_table, referenced_columns, meta)
      end

      def visit({:default, value}) when value in [true, false], do: value

      # Visits a list of AST components, processing each recursively.
      @spec visit(list(), map()) :: list()
      def visit(components, opts) when is_list(components) do
        Enum.map(components, &visit(&1, opts))
      end

      # Visits a tuple by converting it to a list and processing.
      @spec visit(tuple(), map()) :: term()
      def visit(value, opts) when is_tuple(value), do: visit(Tuple.to_list(value), opts)

      # Catch-all visitor for unrecognized AST nodes. Returns value unchanged.
      @spec visit(term(), map()) :: term()
      def visit(value, _opts), do: value
    end
  end
end
