defmodule Drops.SQL.Database do
  @moduledoc """
  Database introspection and compilation interface for SQL databases.

  This module provides a unified interface for database introspection across different
  SQL database adapters (PostgreSQL, SQLite). It defines the core types used in the
  AST representation of database structures and provides functions to introspect
  and compile database tables into structured data.

  ## Architecture

  The module follows a behavior-based approach where each database adapter implements
  the `introspect_table/2` callback to provide database-specific introspection logic.
  The introspected data is returned as an AST (Abstract Syntax Tree) that is then
  compiled into structured `Drops.SQL.Database.Table` structs using adapter-specific
  compilers.

  ## Supported Adapters

  - **PostgreSQL** - via `Drops.SQL.Postgres`
  - **SQLite** - via `Drops.SQL.Sqlite`

  ## AST Types

  The module defines several types that represent the AST structure returned by
  database introspection:

  - `name/0` - Represents identifiers (table names, column names, etc.)
  - `db_type/0` - Represents database-specific column types
  - `meta/0` - Represents metadata maps with additional information
  - `column/0` - Represents a database column with type and metadata
  - `foreign_key/0` - Represents foreign key constraints
  - `index/0` - Represents database indices
  - `table/0` - Represents a complete table with all components

  ## Usage

      # Introspect a table using the main interface
      {:ok, table} = Drops.SQL.Database.table("users", MyApp.Repo)

      # The table struct contains all metadata
      %Drops.SQL.Database.Table{
        name: :users,
        columns: [...],
        primary_key: %Drops.SQL.Database.PrimaryKey{...},
        foreign_keys: [...],
        indices: [...]
      }

  ## Implementing New Adapters

  To add support for a new database adapter:

  1. Create a module that uses `Drops.SQL.Database`
  2. Implement the `introspect_table/2` callback
  3. Create a corresponding compiler module that uses `Drops.SQL.Compiler`
  4. Add the adapter to the `get_database_adapter/1` function

  Example:

      defmodule Drops.SQL.MyAdapter do
        use Drops.SQL.Database, adapter: :my_adapter, compiler: Drops.SQL.Compilers.MyAdapter

        @impl true
        def introspect_table(table_name, repo) do
          # Implementation specific to your database
        end
      end
  """

  alias Drops.SQL.{Postgres, Sqlite}
  alias Drops.SQL.Database.Table

  @typedoc """
  Represents an identifier in the database AST.

  Used for table names, column names, index names, etc.
  """
  @type name :: {:identifier, String.t()}

  @typedoc """
  Represents a database type in the AST.

  The term can be a string (raw database type) or an atom (normalized type).
  """
  @type db_type :: {:type, term()}

  @typedoc """
  Represents metadata in the AST.

  Contains additional information about database objects like constraints,
  defaults, nullability, etc.
  """
  @type meta :: {:meta, map()}

  @typedoc """
  Represents a database column in the AST.

  Contains the column name, type, and metadata.
  """
  @type column :: {:column, {name(), db_type(), meta()}}

  @typedoc """
  Represents a foreign key constraint in the AST.

  Contains the constraint name, source columns, referenced table,
  referenced columns, and metadata.
  """
  @type foreign_key ::
          {:foreign_key, {name(), [name()], name(), [name()], meta()}}

  @typedoc """
  Represents a database index in the AST.

  Contains the index name, indexed columns, and metadata.
  """
  @type index :: {:index, {name(), [name()], meta()}}

  @typedoc """
  Represents a complete database table in the AST.

  Contains the table name and all its components: columns, foreign keys, and indices.
  """
  @type table :: {:table, {name(), [column()], [foreign_key()], [index()]}}

  @doc """
  Callback for database adapters to implement table introspection.

  This callback should return the complete table structure as an AST that can
  be processed by the corresponding compiler.

  ## Parameters

  - `table_name` - The name of the table to introspect
  - `repo` - The Ecto repository module to use for database queries

  ## Returns

  - `{:ok, table()}` - Successfully introspected table AST
  - `{:error, term()}` - Error during introspection
  """
  @callback introspect_table(String.t(), module()) :: {:ok, table()} | {:error, term()}

  @doc """
  Macro for implementing database adapter modules.

  This macro sets up the necessary behavior implementation and provides
  a `table/2` function that combines introspection and compilation.

  ## Options

  - `:adapter` - The adapter identifier (e.g., `:postgres`, `:sqlite`)
  - `:compiler` - The compiler module to use for AST processing

  ## Generated Functions

  - `opts/0` - Returns the adapter options
  - `adapter/0` - Returns the adapter identifier
  - `table/2` - Introspects and compiles a table

  ## Example

      defmodule MyAdapter do
        use Drops.SQL.Database, adapter: :my_db, compiler: MyCompiler

        @impl true
        def introspect_table(table_name, repo) do
          # Implementation
        end
      end
  """
  defmacro __using__(opts) do
    quote location: :keep do
      alias Drops.SQL.Database

      @behaviour Database

      @opts unquote(opts)
      @doc """
      Returns the adapter configuration options.
      """
      @spec opts() :: keyword()
      def opts, do: @opts

      @adapter unquote(opts[:adapter])
      @doc """
      Returns the adapter identifier.
      """
      @spec adapter() :: atom()
      def adapter, do: @adapter

      @doc """
      Introspects and compiles a database table.

      This function combines the introspection and compilation steps,
      returning a fully structured `Drops.SQL.Database.Table` struct.

      ## Parameters

      - `name` - The table name to introspect
      - `repo` - The Ecto repository module

      ## Returns

      - `{:ok, Table.t()}` - Successfully compiled table
      - `{:error, term()}` - Error during introspection or compilation
      """
      @spec table(String.t(), module()) :: {:ok, Table.t()} | {:error, term()}
      def table(name, repo) do
        case introspect_table(name, repo) do
          {:ok, ast} -> Database.compile_table(unquote(opts[:compiler]), ast, Map.new(opts()))
          error -> error
        end
      end
    end
  end

  @doc """
  Main interface for table introspection and compilation.

  This function automatically detects the database adapter from the repository
  and delegates to the appropriate adapter module for introspection and compilation.

  ## Parameters

  - `name` - The table name to introspect
  - `repo` - The Ecto repository module

  ## Returns

  - `{:ok, Table.t()}` - Successfully compiled table structure
  - `{:error, term()}` - Error during introspection, compilation, or unsupported adapter

  ## Examples

      # Introspect a users table
      {:ok, table} = Drops.SQL.Database.table("users", MyApp.Repo)

      # Access table components
      table.name          # :users
      table.columns       # [%Column{...}, ...]
      table.primary_key   # %PrimaryKey{...}
      table.foreign_keys  # [%ForeignKey{...}, ...]
      table.indices       # [%Index{...}, ...]

  ## Errors

  Returns `{:error, {:unsupported_adapter, adapter}}` if the repository uses
  an unsupported database adapter.
  """
  @spec table(String.t(), module()) :: {:ok, Table.t()} | {:error, term()}
  def table(name, repo) do
    case get_database_adapter(repo) do
      {:ok, adapter} ->
        adapter.table(name, repo)

      error ->
        error
    end
  end

  @doc """
  Compiles a database table AST into a structured Table struct.

  This function takes the AST returned by adapter introspection and processes
  it through the specified compiler to produce a `Drops.SQL.Database.Table` struct.

  ## Parameters

  - `compiler` - The compiler module to use (e.g., `Drops.SQL.Compilers.Postgres`)
  - `ast` - The table AST returned by introspection
  - `opts` - Compilation options (typically includes adapter information)

  ## Returns

  - `{:ok, Table.t()}` - Successfully compiled table
  - `{:error, term()}` - Error during compilation

  ## Examples

      # Typically called internally by adapter modules
      ast = {:table, {{:identifier, "users"}, columns, foreign_keys, indices}}
      {:ok, table} = Drops.SQL.Database.compile_table(
        Drops.SQL.Compilers.Postgres,
        ast,
        adapter: :postgres
      )
  """
  @spec compile_table(module(), table(), map()) :: {:ok, Table.t()} | {:error, term()}
  def compile_table(compiler, ast, opts) do
    case compiler.process(ast, opts) do
      %Table{} = table -> {:ok, table}
      error -> error
    end
  end

  # Determines the appropriate database adapter module from an Ecto repository.
  # Examines the repository's adapter and returns the corresponding Drops.SQL adapter module.
  # Returns {:ok, module()} for supported adapters or {:error, {:unsupported_adapter, module()}} for unsupported ones.
  # Supported: Ecto.Adapters.Postgres → Drops.SQL.Postgres, Ecto.Adapters.SQLite3 → Drops.SQL.Sqlite
  @spec get_database_adapter(module()) ::
          {:ok, module()} | {:error, {:unsupported_adapter, module()}}
  defp get_database_adapter(repo) do
    case repo.__adapter__() do
      Ecto.Adapters.SQLite3 ->
        {:ok, Sqlite}

      Ecto.Adapters.Postgres ->
        {:ok, Postgres}

      adapter ->
        {:error, {:unsupported_adapter, adapter}}
    end
  end
end
