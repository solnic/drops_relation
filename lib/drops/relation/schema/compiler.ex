defmodule Drops.Relation.Schema.Compiler do
  @moduledoc """
  Compiler for converting SQL Database structures to Relation Schema structures.

  This module follows the same pattern as Drops.SQL.Compiler but works with
  SQL Database structs (Table, Column, PrimaryKey, ForeignKey, Index) and
  converts them to Drops.Relation.Schema structs.

  The compiler replaces the Inference protocol implementations that were
  previously defined on individual SQL Database components.

  ## Usage

      # Convert a SQL Database Table to a Relation Schema
      {:ok, table} = Database.table("users", MyApp.Repo)
      schema = Drops.Relation.Schema.Compiler.visit(table, opts)

  ## Examples

      iex> alias Drops.SQL.Database
      iex> table = %Database.Table{name: "users", columns: [...], ...}
      iex> schema = Drops.Relation.Schema.Compiler.visit(table, [])
      iex> schema.source
      "users"
  """

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.{Field, PrimaryKey, ForeignKey, Index}
  alias Drops.SQL.Database
  alias Drops.SQL.Types

  @doc """
  Main entry point for converting SQL Database Table to Relation Schema.

  ## Parameters

  - `table` - A Drops.SQL.Database.Table struct
  - `opts` - Optional compilation options

  ## Returns

  A Drops.Relation.Schema.t() struct.

  ## Examples

      iex> table = %Drops.SQL.Database.Table{name: "users", ...}
      iex> schema = Drops.Relation.Schema.Compiler.visit(table, [])
      iex> %Drops.Relation.Schema{} = schema
  """

  @components [{:name, :source}, {:columns, :fields}, :primary_key, :foreign_keys, :indices]
  def visit(%Database.Table{} = table, opts) do
    attributes =
      Enum.reduce(@components, %{}, fn spec, acc ->
        [source_key, target_key] =
          case spec do
            {source, target} -> [source, target]
            name -> [name, name]
          end

        new_opts = Keyword.merge(opts, Enum.to_list(acc))
        component = visit(Map.get(table, source_key), Keyword.put(new_opts, :table, table))
        Map.put(acc, target_key, component)
      end)

    Schema.new(attributes)
  end

  def visit(%Database.Column{} = column, opts) do
    table = opts[:table]

    ecto_type = Types.Conversion.to_ecto_type(table, column)
    atom_type = Types.Conversion.to_atom(table, ecto_type)

    meta = %{
      type: atom_type,
      source: column.name,
      primary_key: column.meta.primary_key,
      foreign_key: Database.Table.foreign_key_column?(table, column.name),
      nullable: column.meta.nullable,
      default: column.meta.default,
      check_constraints: column.meta.check_constraints
    }

    Field.new(column.name, ecto_type, meta)
  end

  def visit(%Database.PrimaryKey{} = primary_key, opts) do
    fields = Enum.filter(opts[:fields], fn field -> field.name in primary_key.columns end)

    PrimaryKey.new(fields)
  end

  def visit(%Database.ForeignKey{} = foreign_key, _opts) do
    field_name = List.first(foreign_key.columns)
    referenced_field = List.first(foreign_key.referenced_columns)

    # Generate association name from field name (remove _id suffix if present)
    association_name =
      field_name
      |> Atom.to_string()
      |> String.replace(~r/_id$/, "")
      |> String.to_atom()

    ForeignKey.new(field_name, foreign_key.referenced_table, referenced_field, association_name)
  end

  def visit(%Database.Index{} = index, opts) do
    fields = opts[:fields] |> Enum.filter(&(&1.name in index.columns))

    Index.new(index.name, fields, index.meta.unique, index.meta.type)
  end

  def visit(node, opts) when is_list(node) do
    Enum.map(node, &visit(&1, opts))
  end

  def visit(value, _opts), do: value
end
