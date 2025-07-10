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
        type: "integer",
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

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          nullable: boolean(),
          default: term(),
          primary_key: boolean(),
          check_constraints: [String.t()]
        }

  defstruct [
    :name,
    :type,
    :nullable,
    :default,
    :primary_key,
    check_constraints: []
  ]

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
  @spec new(String.t(), String.t(), boolean(), term(), boolean(), [String.t()]) :: t()
  def new(name, type, nullable, default, primary_key, check_constraints \\ []) do
    %__MODULE__{
      name: name,
      type: type,
      nullable: nullable,
      default: default,
      primary_key: primary_key,
      check_constraints: check_constraints
    }
  end

  @doc """
  Creates a Column struct from introspection data.

  This is a convenience function for creating columns from the raw data
  returned by database introspection queries.

  ## Parameters

  - `introspection_data` - A map with column metadata from database introspection

  ## Examples

      iex> data = %{
      ...>   name: "email",
      ...>   type: "varchar(255)",
      ...>   not_null: false,
      ...>   default: nil,
      ...>   primary_key: false,
      ...>   check_constraints: []
      ...> }
      iex> Drops.SQL.Database.Column.from_introspection(data)
      %Drops.SQL.Database.Column{
        name: "email",
        type: "varchar(255)",
        nullable: true,
        default: nil,
        primary_key: false,
        check_constraints: []
      }
  """
  @spec from_introspection(map()) :: t()
  def from_introspection(data) when is_map(data) do
    %__MODULE__{
      name: Map.get(data, :name) || Map.get(data, "name"),
      type: Map.get(data, :type) || Map.get(data, "type"),
      nullable:
        to_boolean(not (Map.get(data, :not_null, false) || Map.get(data, "not_null", false))),
      default: Map.get(data, :default) || Map.get(data, "default"),
      primary_key:
        to_boolean(Map.get(data, :primary_key, false) || Map.get(data, "primary_key", false)),
      check_constraints:
        Map.get(data, :check_constraints, []) || Map.get(data, "check_constraints", [])
    }
  end

  # Helper function to safely convert values to boolean
  defp to_boolean(value) do
    case value do
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      1 -> true
      0 -> false
      _ -> false
    end
  end

  @doc """
  Checks if the column is part of a primary key.

  ## Examples

      iex> column = Drops.SQL.Database.Column.new("id", "integer", false, nil, true)
      iex> Drops.SQL.Database.Column.primary_key?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.primary_key?(column)
      false
  """
  @spec primary_key?(t()) :: boolean()
  def primary_key?(%__MODULE__{primary_key: primary_key}), do: primary_key

  @doc """
  Checks if the column allows NULL values.

  ## Examples

      iex> column = Drops.SQL.Database.Column.new("email", "varchar(255)", true, nil, false)
      iex> Drops.SQL.Database.Column.nullable?(column)
      true

      iex> column = Drops.SQL.Database.Column.new("id", "integer", false, nil, true)
      iex> Drops.SQL.Database.Column.nullable?(column)
      false
  """
  @spec nullable?(t()) :: boolean()
  def nullable?(%__MODULE__{nullable: nullable}), do: nullable

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
  def has_default?(%__MODULE__{default: default}), do: not is_nil(default)

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
  def has_check_constraints?(%__MODULE__{check_constraints: constraints}),
    do: constraints != []

  defimpl Drops.Relation.Schema.Field.Inference do
    alias Drops.SQL.Database
    alias Drops.SQL.Database.Table
    alias Drops.SQL.Types
    alias Drops.Relation.Schema

    def to_schema_field(%Database.Column{} = column, %Database.Table{} = table) do
      atom_name = String.to_atom(column.name)
      ecto_type = Types.Conversion.to_ecto_type(table, column)
      atom_type = Types.Conversion.to_atom(table, ecto_type)

      meta = %{
        primary_key: column.primary_key,
        foreign_key: Table.foreign_key_column?(table, column.name),
        nullable: column.nullable,
        default: column.default,
        check_constraints: column.check_constraints
      }

      Schema.Field.new(atom_name, atom_type, ecto_type, atom_name, meta)
    end
  end
end
