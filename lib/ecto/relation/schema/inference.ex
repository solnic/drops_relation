defprotocol Ecto.Relation.Schema.Inference do
  @moduledoc """
  Protocol for converting database introspection components to Ecto.Relation.Schema components.

  This protocol allows different database components (columns, primary keys, foreign keys, indexes)
  to define how they should be converted to their corresponding schema representations.
  This enables customization and extensibility for different database types and special cases.
  """

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
      iex> field = Ecto.Relation.Schema.Inference.to_schema_component(column, table)
      iex> field.name
      :email
  """
  @spec to_schema_component(term(), term()) :: term()
  def to_schema_component(component, table)
end
