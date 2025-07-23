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

  This callback must be implemented by each database adapter module to provide
  database-specific logic for introspecting table structures. The implementation
  should query the database's system catalogs or information schema to extract
  complete table metadata and return it as a structured AST.

  The returned AST should include all table components: columns with their types
  and metadata, primary key information, foreign key constraints, and indices.
  This AST will then be processed by the adapter's corresponding compiler.

  ## Parameters

  - `table_name` - The name of the database table to introspect (as a string)
  - `repo` - The Ecto repository module configured for database access

  ## Returns

  - `{:ok, table()}` - Successfully introspected table AST following the `table()` type specification
  - `{:error, term()}` - Error during introspection (table not found, permission denied, etc.)

  ## Implementation Requirements

  Implementations must:
  1. Query the database for table metadata using the repository connection
  2. Extract column information including names, types, nullability, defaults
  3. Identify primary key constraints
  4. Discover foreign key relationships
  5. List table indices
  6. Return all data as a properly structured AST

  ## Example Implementation Structure

      @impl true
      def introspect_table(table_name, repo) do
        with {:ok, columns} <- get_columns(table_name, repo),
             {:ok, primary_key} <- get_primary_key(table_name, repo),
             {:ok, foreign_keys} <- get_foreign_keys(table_name, repo),
             {:ok, indices} <- get_indices(table_name, repo) do
          {:ok, build_table_ast(table_name, columns, primary_key, foreign_keys, indices)}
        end
      end
  """
  @callback introspect_table(String.t(), module()) :: {:ok, table()} | {:error, term()}

  @doc """
  Macro for implementing database adapter modules.

  This macro provides the foundation for creating database adapter modules by
  setting up the necessary behavior implementation, generating helper functions,
  and providing a unified `table/2` interface that combines introspection and compilation.

  When you `use Drops.SQL.Database`, the macro automatically:
  1. Sets up the `Drops.SQL.Database` behavior
  2. Generates helper functions for accessing adapter configuration
  3. Creates a `table/2` function that orchestrates introspection and compilation
  4. Requires you to implement the `introspect_table/2` callback

  ## Options

  - `:adapter` - The adapter identifier atom (e.g., `:postgres`, `:sqlite`, `:mysql`)
  - `:compiler` - The compiler module to use for processing AST (e.g., `Drops.SQL.Compilers.Postgres`)

  ## Generated Functions

  The macro generates these functions in your adapter module:

  - `opts/0` - Returns the complete adapter configuration as a keyword list
  - `adapter/0` - Returns the adapter identifier atom for easy access
  - `table/2` - High-level interface that introspects and compiles a table in one call

  ## Usage Example

      defmodule Drops.SQL.MyDatabase do
        use Drops.SQL.Database,
          adapter: :my_database,
          compiler: Drops.SQL.Compilers.MyDatabase

        @impl true
        def introspect_table(table_name, repo) do
          # Your database-specific introspection logic
          with {:ok, raw_data} <- query_system_tables(table_name, repo) do
            {:ok, build_ast(raw_data)}
          end
        end

        # Private helper functions for introspection
        defp query_system_tables(table_name, repo) do
          # Implementation specific to your database
        end

        defp build_ast(raw_data) do
          # Convert raw database data to AST format
        end
      end

  ## Implementation Requirements

  After using this macro, you must implement:
  - `introspect_table/2` callback - The core introspection logic for your database

  ## Generated table/2 Function

  The generated `table/2` function provides a complete introspection and compilation pipeline:

      {:ok, table} = MyAdapter.table("users", MyApp.Repo)
      # This internally calls:
      # 1. MyAdapter.introspect_table("users", MyApp.Repo)
      # 2. Drops.SQL.Database.compile_table(compiler, ast, opts)
  """
  defmacro __using__(opts) do
    quote location: :keep do
      alias Drops.SQL.Database

      @behaviour Database

      @opts unquote(opts)
      @doc """
      Returns the complete adapter configuration options.

      This function provides access to all configuration options passed to the
      `use Drops.SQL.Database` macro, including the adapter identifier and compiler module.

      ## Returns

      A keyword list containing all adapter configuration options.

      ## Examples

          MyAdapter.opts()
          # => [adapter: :postgres, compiler: Drops.SQL.Compilers.Postgres]
      """
      @spec opts() :: keyword()
      def opts, do: @opts

      @adapter unquote(opts[:adapter])
      @doc """
      Returns the database adapter identifier.

      This function provides quick access to the adapter identifier atom that
      was specified in the `use Drops.SQL.Database` configuration.

      ## Returns

      The adapter identifier atom.

      ## Examples

          MyAdapter.adapter()
          # => :postgres
      """
      @spec adapter() :: atom()
      def adapter, do: @adapter

      @doc """
      Introspects and compiles a database table into a structured representation.

      This function provides the main interface for the adapter, combining both
      introspection and compilation steps into a single operation. It calls the
      adapter's `introspect_table/2` implementation and then processes the resulting
      AST through the configured compiler.

      ## Parameters

      - `name` - The name of the database table to introspect (as a string)
      - `repo` - The Ecto repository module configured for database access

      ## Returns

      - `{:ok, Table.t()}` - Successfully compiled table with complete metadata
      - `{:error, term()}` - Error during introspection or compilation

      ## Examples

          # Introspect a users table
          {:ok, table} = MyAdapter.table("users", MyApp.Repo)

          # Access the compiled table data
          table.name          # :users
          table.columns       # [%Column{...}, ...]
          table.primary_key   # %PrimaryKey{...}

      ## Error Handling

          case MyAdapter.table("users", MyApp.Repo) do
            {:ok, table} ->
              process_table(table)
            {:error, reason} ->
              Logger.error("Failed to introspect table: \#{inspect(reason)}")
          end
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
  Introspects and compiles a database table into a structured representation.

  This is the main interface for database table introspection. It automatically
  detects the database adapter from the repository configuration and delegates
  to the appropriate adapter module for introspection and compilation.

  The function performs two main operations:
  1. Introspects the table structure using the database-specific adapter
  2. Compiles the raw AST into a structured `Drops.SQL.Database.Table` struct

  ## Parameters

  - `name` - The name of the database table to introspect (as a string)
  - `repo` - The Ecto repository module configured for your database

  ## Returns

  - `{:ok, Table.t()}` - Successfully compiled table structure with all metadata
  - `{:error, {:unsupported_adapter, module()}}` - Repository uses unsupported adapter
  - `{:error, term()}` - Database error during introspection or compilation error

  ## Examples

      # Introspect a users table
      {:ok, table} = Drops.SQL.Database.table("users", MyApp.Repo)

      # Access table metadata
      table.name          # :users (converted to atom)
      table.columns       # [%Column{name: :id, type: :integer, ...}, ...]
      table.primary_key   # %PrimaryKey{fields: [:id]}
      table.foreign_keys  # [%ForeignKey{field: :user_id, ...}, ...]
      table.indices       # [%Index{name: :users_email_index, ...}, ...]

      # Handle errors
      case Drops.SQL.Database.table("nonexistent", MyApp.Repo) do
        {:ok, result} ->
          IO.puts("Found table: \#{result.name}")
        {:error, reason} ->
          IO.puts("Error: \#{inspect(reason)}")
      end

  ## Supported Adapters

  - PostgreSQL via `Ecto.Adapters.Postgres`
  - SQLite via `Ecto.Adapters.SQLite3`

  ## Error Cases

  The function can return errors in several scenarios:
  - Unsupported database adapter
  - Table does not exist in the database
  - Database connection issues
  - Permission issues accessing table metadata
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

  This function processes the raw AST (Abstract Syntax Tree) returned by database
  adapter introspection through the specified compiler module to produce a fully
  structured `Drops.SQL.Database.Table` struct with normalized data types and metadata.

  This is typically called internally by adapter modules after introspection, but
  can be used directly if you have a pre-built AST from another source.

  ## Parameters

  - `compiler` - The compiler module to use for processing the AST (e.g., `Drops.SQL.Compilers.Postgres`)
  - `ast` - The table AST returned by introspection, following the `table()` type specification
  - `opts` - Compilation options map, typically includes adapter information and other metadata

  ## Returns

  - `{:ok, Table.t()}` - Successfully compiled table with normalized types and metadata
  - `{:error, term()}` - Error during compilation, such as invalid AST structure or compiler issues

  ## Examples

      # Typically called internally by adapter modules
      ast = {:table, {{:identifier, "users"}, columns, foreign_keys, indices}}
      {:ok, table} = Drops.SQL.Database.compile_table(
        Drops.SQL.Compilers.Postgres,
        ast,
        %{adapter: :postgres}
      )

      # The resulting table struct contains normalized data
      table.name          # :users (atom)
      table.columns       # [%Column{...}] with normalized types
      table.primary_key   # %PrimaryKey{...}

  ## AST Structure

  The AST must follow the `table()` type specification:
  - `{:table, {name, columns, foreign_keys, indices}}`
  - Where each component follows its respective AST type definition

  ## Compiler Requirements

  The compiler module must implement a `process/2` function that accepts
  the AST and options, returning either a `Table.t()` struct or an error.
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
