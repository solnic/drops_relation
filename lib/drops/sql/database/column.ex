defmodule Drops.SQL.Database.Column do
  @moduledoc """
  Represents a database column with complete metadata.

  This struct stores comprehensive information about a database column including
  its name, type, constraints, and other metadata extracted from database introspection.

  ## Examples

      # Simple column
      %Drops.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false
      }

      # Primary key column
      %Drops.SQL.Database.Column{
        name: "id",
        type: :integer,
        nullable: false,
        default: nil,
        primary_key: true
      }

      # Column with constraints
      %Drops.SQL.Database.Column{
        name: "status",
        type: "varchar(20)",
        nullable: false,
        default: "active",
        primary_key: false,
        check_constraints: ["status IN ('active', 'inactive')"]
      }
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

  ## Parameters

  - `name` - The column name as a string
  - `type` - The database type as a string
  - `nullable` - Whether the column allows NULL values
  - `default` - The default value for the column
  - `primary_key` - Whether this column is part of the primary key
  - `check_constraints` - List of check constraint expressions

  ## Examples

      iex> Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      %Drops.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false,
        check_constraints: []
      }

      iex> constraints = ["status IN ('active', 'inactive')"]
      iex> Drops.SQL.Database.Column.new("status", "varchar(20)", false, "active", false, constraints)
      %Drops.SQL.Database.Column{
        name: "status",
        type: "varchar(20)",
        nullable: false,
        default: "active",
        primary_key: false,
        check_constraints: ["status IN ('active', 'inactive')"]
      }
  """
  @spec new(atom(), String.t(), meta()) :: t()
  def new(name, type, meta) do
    %__MODULE__{name: name, type: type, meta: meta}
  end

  @doc """
  Checks if the column is part of a primary key.

  ## Examples

      iex> column = Drops.SQL.Database.Column.new("id", :integer, false, nil, true)
      iex> Drops.SQL.Database.Column.primary_key?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.primary_key?(column)
      false
  """
  @spec primary_key?(t()) :: boolean()
  def primary_key?(%__MODULE__{meta: %{primary_key: primary_key}}), do: primary_key

  @doc """
  Checks if the column allows NULL values.

  ## Examples

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.nullable?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("id", :integer, false, nil, true)
      iex> Drops.SQL.Database.Column.nullable?(column)
      false
  """
  @spec nullable?(t()) :: boolean()
  def nullable?(%__MODULE__{meta: %{nullable: nullable}}), do: nullable

  @doc """
  Checks if the column has a default value.

  ## Examples

      iex> column = Drops.SQL.Database.Column.new("status", "varchar(20)", false, "active", false)
      iex> Drops.SQL.Database.Column.has_default?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.has_default?(column)
      false
  """
  @spec has_default?(t()) :: boolean()
  def has_default?(%__MODULE__{meta: %{default: default}}), do: not is_nil(default)

  @doc """
  Checks if the column has check constraints.

  ## Examples

      iex> constraints = ["status IN ('active', 'inactive')"]
      iex> column = Drops.SQL.Database.Column.new("status", "varchar(20)", false, "active", false, constraints)
      iex> Drops.SQL.Database.Column.has_check_constraints?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.has_check_constraints?(column)
      false
  """
  @spec has_check_constraints?(t()) :: boolean()
  def has_check_constraints?(%__MODULE__{meta: %{check_constraints: constraints}}),
    do: constraints != []
end
