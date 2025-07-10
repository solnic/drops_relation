defmodule Drops.Relation.Inference do
  @moduledoc """
  Schema inference utilities for Drops.Relation.

  This module provides functions for inferring database schemas and converting
  them to Drops.Relation.Schema structures.
  """

  def infer_schema(name, repo) do
    case Drops.SQL.Database.table(name, repo) do
      {:ok, table} ->
        Drops.Relation.Compilers.SchemaCompiler.visit(table, [])

      {:error, reason} ->
        raise "Failed to introspect table #{name}: #{inspect(reason)}"
    end
  end
end
