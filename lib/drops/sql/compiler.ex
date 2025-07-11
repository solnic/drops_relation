defmodule Drops.SQL.Compiler do
  alias Drops.SQL.Database.{Table, Column, PrimaryKey, ForeignKey, Index}

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
      def opts, do: @opts

      def process(node, opts) do
        visit(node, Keyword.merge(opts, unquote(opts)))
      end

      def visit({:table, components}, opts) do
        [name, columns, foreign_keys, indices] = visit(components, opts)

        primary_key = PrimaryKey.from_columns(columns)

        Table.new(name, opts[:adapter], columns, primary_key, foreign_keys, indices)
      end

      def visit({:identifier, name}, _opts), do: String.to_atom(name)

      def visit({:column, components}, opts) do
        [name, type, meta] = visit(components, opts)
        Column.new(name, type, meta)
      end

      def visit({:type, type}, _opts), do: type

      def visit({:meta, meta}, opts) when is_map(meta) do
        Enum.reduce(meta, %{}, fn {key, value}, acc ->
          Map.put(acc, key, visit(value, opts))
        end)
      end

      def visit({:index, components}, opts) do
        [name, columns, meta] = visit(components, opts)
        Index.new(name, columns, meta)
      end

      def visit({:foreign_key, components}, opts) do
        [name, columns, referenced_table, referenced_columns, meta] = visit(components, opts)
        ForeignKey.new(name, columns, referenced_table, referenced_columns, meta)
      end

      def visit(components, opts) when is_list(components) do
        Enum.map(components, &visit(&1, opts))
      end

      def visit(value, opts) when is_tuple(value), do: visit(Tuple.to_list(value), opts)

      # Catch-all
      def visit(value, _opts), do: value
    end
  end
end
