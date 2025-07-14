defmodule Drops.SQL.Database.Column do
  @moduledoc """
  Represents a database column with complete metadata.

  This struct stores comprehensive information about a database column including
  its name, type, constraints, and other metadata extracted from database introspection.
  """

  @type meta :: %{
          nullable: boolean(),
          default: term(),
          primary_key: boolean(),
          foreign_key: boolean(),
          check_constraints: [String.t()]
        }

  @type t :: %__MODULE__{name: String.t(), type: String.t(), meta: meta()}

  defstruct [:name, :type, :meta]

  @doc """
  Creates a new Column struct.
  """
  @spec new(atom(), String.t(), meta()) :: t()
  def new(name, type, meta) do
    %__MODULE__{name: name, type: type, meta: meta}
  end
end
