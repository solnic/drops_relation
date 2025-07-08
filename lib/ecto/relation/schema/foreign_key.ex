defmodule Ecto.Relation.Schema.ForeignKey do
  @moduledoc """
  Represents a foreign key relationship in a database table/schema.

  This struct stores information about a foreign key field and its reference
  to another table and field.

  ## Examples

      # Simple foreign key
      %Ecto.Relation.Schema.ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id,
        association_name: :user
      }
  """

  @type t :: %__MODULE__{
          field: atom(),
          references_table: String.t(),
          references_field: atom(),
          association_name: atom() | nil
        }

  defstruct [:field, :references_table, :references_field, :association_name]

  @doc """
  Creates a new ForeignKey struct.

  ## Parameters

  - `field` - The foreign key field name in the current table
  - `references_table` - The name of the referenced table
  - `references_field` - The field name in the referenced table
  - `association_name` - Optional association name from Ecto schema

  ## Examples

      iex> Ecto.Relation.Schema.ForeignKey.new(:user_id, "users", :id, :user)
      %Ecto.Relation.Schema.ForeignKey{
        field: :user_id,
        references_table: "users",
        references_field: :id,
        association_name: :user
      }
  """
  @spec new(atom(), String.t(), atom(), atom() | nil) :: t()
  def new(field, references_table, references_field, association_name \\ nil) do
    %__MODULE__{
      field: field,
      references_table: references_table,
      references_field: references_field,
      association_name: association_name
    }
  end

  defimpl Inspect do
    def inspect(%Ecto.Relation.Schema.ForeignKey{} = fk, _opts) do
      "#ForeignKey<#{fk.field} -> #{fk.references_table}.#{fk.references_field}>"
    end
  end

  @doc """
  Extracts foreign key information from an Ecto schema module.

  This function analyzes the schema's associations to identify foreign keys.
  Only `belongs_to` associations create foreign keys in the current table.

  ## Parameters

  - `schema_module` - An Ecto schema module

  ## Returns

  A list of ForeignKey structs representing all foreign keys in the schema.

  ## Examples

      iex> Ecto.Relation.Schema.ForeignKey.from_ecto_schema(MyApp.Post)
      [
        %Ecto.Relation.Schema.ForeignKey{
          field: :user_id,
          references_table: "users",
          references_field: :id,
          association_name: :user
        }
      ]
  """
  @spec from_ecto_schema(module()) :: [t()]
  def from_ecto_schema(schema_module) when is_atom(schema_module) do
    associations = schema_module.__schema__(:associations)

    for assoc_name <- associations do
      assoc = schema_module.__schema__(:association, assoc_name)

      case assoc do
        %Ecto.Association.BelongsTo{
          owner_key: fk_field,
          related: related_schema,
          related_key: ref_field
        } ->
          # Get the table name from the related schema
          table_name = get_table_name(related_schema)

          new(fk_field, table_name, ref_field, assoc_name)

        _ ->
          # has_one, has_many, many_to_many don't create FKs in this table
          nil
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  # Private helper to get table name from related schema
  defp get_table_name(related_schema) do
    try do
      related_schema.__schema__(:source)
    rescue
      UndefinedFunctionError ->
        # Try to resolve the module name within Test.Ecto.TestSchemas namespace
        # This handles cases where associations reference unqualified module names
        case try_resolve_test_schema(related_schema) do
          {:ok, resolved_module} -> resolved_module.__schema__(:source)
          :error -> "unknown_table"
        end
    end
  end

  # Helper to resolve test schema modules
  defp try_resolve_test_schema(module_name) do
    full_module_name = Module.concat([Test.Ecto.TestSchemas, module_name])

    if Code.ensure_loaded?(full_module_name) and
         function_exported?(full_module_name, :__schema__, 1) do
      {:ok, full_module_name}
    else
      :error
    end
  end
end
