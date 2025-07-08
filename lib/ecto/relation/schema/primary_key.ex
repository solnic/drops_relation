defmodule Ecto.Relation.Schema.PrimaryKey do
  @moduledoc """
  Represents primary key information for a database table/schema.

  This struct stores information about primary key fields, supporting both
  single-column and composite primary keys. Fields are stored as Field structs
  containing complete metadata.

  ## Examples

      # Single primary key
      %Ecto.Relation.Schema.PrimaryKey{
        fields: [%Ecto.Relation.Schema.Field{name: :id, type: :integer, ...}]
      }

      # Composite primary key
      %Ecto.Relation.Schema.PrimaryKey{
        fields: [
          %Ecto.Relation.Schema.Field{name: :user_id, type: :integer, ...},
          %Ecto.Relation.Schema.Field{name: :role_id, type: :integer, ...}
        ]
      }

      # No primary key
      %Ecto.Relation.Schema.PrimaryKey{fields: []}
  """

  alias Ecto.Relation.Schema.Field

  @type t :: %__MODULE__{
          fields: [Field.t()]
        }

  defstruct [:fields]

  @doc """
  Creates a new PrimaryKey struct.

  ## Parameters

  - `fields` - List of Field structs that form the primary key

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([field])
      iex> length(pk.fields)
      1
  """
  @spec new([Field.t()]) :: t()
  def new(fields) when is_list(fields) do
    %__MODULE__{fields: fields}
  end

  @doc """
  Creates a new PrimaryKey struct from field names.

  This is a convenience function for backward compatibility and simple cases.

  ## Parameters

  - `field_names` - List of field names that form the primary key

  ## Examples

      iex> pk = Ecto.Relation.Schema.PrimaryKey.from_names([:id])
      iex> [field] = pk.fields
      iex> field.name
      :id
  """
  @spec from_names([atom()]) :: t()
  def from_names(field_names) when is_list(field_names) do
    fields =
      Enum.map(field_names, fn name ->
        # Create minimal Field structs for backward compatibility
        Field.new(name, :unknown, :unknown, name)
      end)

    new(fields)
  end

  defimpl Inspect do
    def inspect(%Ecto.Relation.Schema.PrimaryKey{} = pk, _opts) do
      case pk.fields do
        [] ->
          "#PrimaryKey<[]>"

        fields ->
          field_names =
            fields
            |> Enum.map(& &1.name)
            |> Enum.join(", ")

          "#PrimaryKey<[#{field_names}]>"
      end
    end
  end

  @doc """
  Checks if the primary key is composite (has multiple fields).

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([field])
      iex> Ecto.Relation.Schema.PrimaryKey.composite?(pk)
      false

      iex> field1 = Ecto.Relation.Schema.Field.new(:user_id, :integer, :id, :user_id)
      iex> field2 = Ecto.Relation.Schema.Field.new(:role_id, :integer, :id, :role_id)
      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([field1, field2])
      iex> Ecto.Relation.Schema.PrimaryKey.composite?(pk)
      true
  """
  @spec composite?(t()) :: boolean()
  def composite?(%__MODULE__{fields: fields}) do
    length(fields) > 1
  end

  @doc """
  Checks if the schema has a primary key.

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([field])
      iex> Ecto.Relation.Schema.PrimaryKey.present?(pk)
      true

      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([])
      iex> Ecto.Relation.Schema.PrimaryKey.present?(pk)
      false
  """
  @spec present?(t()) :: boolean()
  def present?(%__MODULE__{fields: fields}) do
    fields != []
  end

  @doc """
  Gets the field names from the primary key.

  ## Examples

      iex> field = Ecto.Relation.Schema.Field.new(:id, :integer, :id, :id)
      iex> pk = Ecto.Relation.Schema.PrimaryKey.new([field])
      iex> Ecto.Relation.Schema.PrimaryKey.field_names(pk)
      [:id]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  @doc """
  Extracts primary key information from an Ecto schema module.

  ## Parameters

  - `schema_module` - An Ecto schema module

  ## Examples

      iex> # Example with a hypothetical schema
      iex> # Ecto.Relation.Schema.PrimaryKey.from_ecto_schema(MyApp.User)
      iex> # %Ecto.Relation.Schema.PrimaryKey{fields: [%Field{name: :id, ...}]}
      iex> pk = Ecto.Relation.Schema.PrimaryKey.from_names([:id])
      iex> Ecto.Relation.Schema.PrimaryKey.field_names(pk)
      [:id]
  """
  @spec from_ecto_schema(module()) :: t()
  def from_ecto_schema(schema_module) when is_atom(schema_module) do
    field_names = schema_module.__schema__(:primary_key)
    from_names(field_names)
  end
end
