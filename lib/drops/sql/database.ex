defmodule Drops.SQL.Database do
  alias Drops.SQL.{Postgres, Sqlite}
  alias Drops.SQL.Database.Table

  @callback introspect_table(module(), String.t()) :: {:ok, Table.t()} | {:error, term()}

  @callback introspect_table_columns(module(), String.t()) ::
              {:ok, [Column.t()]} | {:error, term()}

  @callback introspect_table_foreign_keys(module(), String.t()) ::
              {:ok, [ForeignKey.t()]} | {:error, term()}

  @callback introspect_table_indices(module(), String.t()) ::
              {:ok, [Index.t()]} | {:error, term()}

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

  def table(name, repo) do
    case get_database_adapter(repo) do
      {:ok, adapter} ->
        adapter.table(name, repo)

      error ->
        error
    end
  end

  def compile_table(compiler, ast, opts) do
    case compiler.process(ast, opts) do
      %Table{} = table -> {:ok, table}
      error -> error
    end
  end

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
