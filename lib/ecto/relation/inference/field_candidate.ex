defmodule Ecto.Relation.Inference.FieldCandidate do
  @moduledoc """
  Represents a field candidate during schema inference.

  This structure helps organize field information and determine where each field
  should be placed in the final schema (primary key attributes, excluded fields,
  regular field definitions, etc.).
  """

  alias Ecto.Relation.Schema.Field

  defstruct [
    # The Field struct with all metadata
    :field,
    # :inferred | :custom | :merged
    :source,
    # :primary_key | :foreign_key | :regular | :timestamp | :excluded
    :category,
    # :attribute | :field_definition | :excluded | :timestamps_macro
    :placement
  ]

  @type t :: %__MODULE__{
          field: Field.t(),
          source: :inferred | :custom | :merged,
          category: :primary_key | :foreign_key | :regular | :timestamp | :excluded,
          placement: :attribute | :field_definition | :excluded | :timestamps_macro
        }

  @doc """
  Creates a new FieldCandidate from a Field struct.
  """
  @spec new(Field.t(), atom(), atom()) :: t()
  def new(%Field{} = field, source, category) do
    placement = determine_placement(field, category)

    %__MODULE__{
      field: field,
      source: source,
      category: category,
      placement: placement
    }
  end

  # Determines where a field should be placed in the final schema.
  @spec determine_placement(Field.t(), atom()) :: atom()
  defp determine_placement(%Field{name: name, ecto_type: ecto_type}, category) do
    case category do
      :primary_key ->
        cond do
          # Default Ecto primary key - exclude (Ecto adds automatically)
          name == :id and ecto_type == :id ->
            :excluded

          # Custom primary keys need @primary_key attribute only (no field definition)
          # Ecto automatically adds the field to __schema__(:fields) when @primary_key is used
          true ->
            :attribute
        end

      :composite_primary_key ->
        # Composite primary key fields are defined as regular fields with primary_key: true
        :field_definition

      :timestamp ->
        # Timestamp fields use the timestamps() macro
        :timestamps_macro

      :excluded ->
        # Fields that should not appear in the schema
        :excluded

      _ ->
        # Regular fields and foreign keys are defined as field() calls
        :field_definition
    end
  end

  @doc """
  Categorizes a field based on its characteristics and context.
  """
  @spec categorize_field(Field.t(), [atom()], boolean(), boolean(), boolean()) :: atom()
  def categorize_field(
        %Field{name: name},
        primary_key_names,
        is_association_fk,
        is_composite_pk \\ false,
        is_foreign_key \\ false
      ) do
    cond do
      name in primary_key_names and is_composite_pk ->
        :composite_primary_key

      name in primary_key_names ->
        :primary_key

      name in [:inserted_at, :updated_at] ->
        :timestamp

      is_association_fk ->
        :excluded

      is_foreign_key ->
        :foreign_key

      true ->
        :regular
    end
  end
end
