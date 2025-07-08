defprotocol Ecto.Relation.Inference.SchemaFieldAST do
  @moduledoc """
  Protocol for generating Ecto schema AST from field definitions.

  This protocol allows users to customize how field definitions are converted
  to Ecto schema AST. It provides two main functions:

  - `to_field_ast/1` - Generates a quoted expression with `field(...)` definition
  - `to_attribute_ast/1` - Generates a quoted expression with an attribute definition
    like `@primary_key {:id, :binary_id, autogenerate: true}`

  ## Usage

  The protocol is automatically implemented for `Ecto.Relation.Schema.Field` structs
  with sensible defaults. Users can provide custom implementations for their own
  field types when the default inference doesn't work as expected.

  ## Examples

      # Custom field type
      defmodule MyApp.CustomField do
        defstruct [:name, :type, :options]
      end

      # Custom protocol implementation
      defimpl Ecto.Relation.Inference.SchemaFieldAST, for: MyApp.CustomField do
        def to_field_ast(%MyApp.CustomField{name: name, type: type, options: opts}) do
          quote do
            Ecto.Schema.field(unquote(name), unquote(type), unquote(opts))
          end
        end

        def to_attribute_ast(%MyApp.CustomField{}) do
          # Return nil if no attribute is needed
          nil
        end
      end
  """

  @doc """
  Generates a quoted expression with a `field(...)` definition.

  ## Parameters

  - `field` - The field struct to generate AST for

  ## Returns

  A quoted expression representing the field definition, or `nil` if no field
  definition should be generated (e.g., for excluded fields).

  ## Examples

      iex> field = %Ecto.Relation.Schema.Field{name: :email, ecto_type: :string, source: :email}
      iex> Ecto.Relation.Inference.SchemaFieldAST.to_field_ast(field)
      {:field, [], [:email, :string]}
  """
  @spec to_field_ast(term()) :: Macro.t() | nil
  def to_field_ast(field)

  @doc """
  Generates a quoted expression with a `field(...)` definition, taking into account
  the field's category in the schema.

  ## Parameters

  - `field` - The field struct to generate AST for
  - `category` - The field category (:regular, :primary_key, :composite_primary_key, etc.)

  ## Returns

  A quoted expression representing the field definition, or `nil` if no field
  definition should be generated.

  ## Examples

      iex> field = %Ecto.Relation.Schema.Field{name: :id, ecto_type: :id, source: :id}
      iex> Ecto.Relation.Inference.SchemaFieldAST.to_field_ast_with_category(field, :composite_primary_key)
      {:field, [], [:id, :id, [primary_key: true]]}
  """
  @spec to_field_ast_with_category(term(), atom()) :: Macro.t() | nil
  def to_field_ast_with_category(field, category)

  @doc """
  Generates a quoted expression with an attribute definition.

  ## Parameters

  - `field` - The field struct to generate attribute AST for

  ## Returns

  A quoted expression representing an attribute definition (like `@primary_key`
  or `@foreign_key_type`), or `nil` if no attribute is needed.

  ## Examples

      iex> field = %Ecto.Relation.Schema.Field{name: :id, ecto_type: :binary_id}
      iex> Ecto.Relation.Inference.SchemaFieldAST.to_attribute_ast(field)
      {:@, [], [{:primary_key, [], [{:id, :binary_id, [autogenerate: true]}]}]}
  """
  @spec to_attribute_ast(term()) :: Macro.t() | nil
  def to_attribute_ast(field)
end
