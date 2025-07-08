defprotocol Ecto.Relation.SQL.DatabaseToSchema do
  @moduledoc """
  Protocol for converting database introspection components to Ecto.Relation.Schema components.

  This protocol allows different database components (columns, primary keys, foreign keys, indexes)
  to define how they should be converted to their corresponding schema representations.
  This enables customization and extensibility for different database types and special cases.

  ## Examples

      # Convert a column to a field
      alias Ecto.Relation.SQL.Database.Column
      column = %Column{name: "email", type: "varchar(255)", ...}
      field = Ecto.Relation.SQL.DatabaseToSchema.to_schema_component(column)

      # Convert a primary key with column context
      alias Ecto.Relation.SQL.Database.PrimaryKey
      pk = %PrimaryKey{columns: ["id"]}
      schema_pk = Ecto.Relation.SQL.DatabaseToSchema.to_schema_component(pk, columns)
  """

  @doc """
  Converts a database component to its corresponding schema representation.

  The specific conversion depends on the type of the component:
  - Column -> Field
  - PrimaryKey -> PrimaryKey (requires columns context, use to_schema_component/2)
  - ForeignKey -> ForeignKey
  - Index -> Index

  ## Parameters

  - `component` - A database component struct (Column, ForeignKey, or Index)

  ## Returns

  The corresponding schema struct.

  ## Examples

      iex> column = %Database.Column{name: "email", type: "varchar(255)", ...}
      iex> field = Ecto.Relation.SQL.DatabaseToSchema.to_schema_component(column)
      iex> field.name
      :email
  """
  @spec to_schema_component(term()) :: term()
  def to_schema_component(component)

  @doc """
  Converts a database component to its corresponding schema representation with context.

  This is used when the conversion requires additional context, such as converting
  a Column which needs access to the table information for proper type inference.

  ## Parameters

  - `component` - A database component struct (Column, PrimaryKey, ForeignKey, or Index)
  - `table` - The Table struct containing the component (provides adapter and context)

  ## Returns

  The corresponding schema struct.

  ## Examples

      iex> column = %Database.Column{name: "email", type: "varchar(255)", ...}
      iex> table = %Database.Table{adapter: :postgres, ...}
      iex> field = Ecto.Relation.SQL.DatabaseToSchema.to_schema_component(column, table)
      iex> field.name
      :email
  """
  @spec to_schema_component(term(), term()) :: term()
  def to_schema_component(component, table)
end
