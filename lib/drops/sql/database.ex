defmodule Drops.SQL.Database do
  alias Drops.SQL.{Postgres, Sqlite}
  alias Drops.SQL.Database.Table

  @type name :: {:identifier, String.t()}

  @type db_type :: {:type, term()}

  @type meta :: {:meta, map()}

  @type column :: {:column, {name(), db_type(), meta()}}

  @type foreign_key ::
          {:foreign_key, {name(), [name()], name(), [name()], meta()}}

  @type index :: {:index, {name(), [name()], meta()}}

  @type table :: {:table, {name(), [column()], [foreign_key()], [index()]}}

  @callback introspect_table(String.t(), module()) :: {:ok, table()} | {:error, term()}

  defmacro __using__(opts) do
    quote location: :keep do
      alias Drops.SQL.Database

      @behaviour Database

      @opts unquote(opts)
      def opts, do: @opts

      @adapter unquote(opts[:adapter])
      def adapter, do: @adapter

      def table(name, repo) do
        case introspect_table(name, repo) do
          {:ok, ast} -> Database.compile_table(unquote(opts[:compiler]), ast, opts())
          error -> error
        end
      end
    end
  end

  @spec table(String.t(), module()) :: {:ok, Table.t()} | {:error, term()}
  def table(name, repo) do
    case get_database_adapter(repo) do
      {:ok, adapter} ->
        adapter.table(name, repo)

      error ->
        error
    end
  end

  @spec compile_table(module(), table(), keyword()) :: {:ok, Table.t()} | {:error, term()}
  def compile_table(compiler, ast, opts) do
    case compiler.process(ast, opts) do
      %Table{} = table -> {:ok, table}
      error -> error
    end
  end

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
