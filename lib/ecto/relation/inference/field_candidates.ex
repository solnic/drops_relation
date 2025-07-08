defmodule Ecto.Relation.Inference.FieldCandidates do
  @moduledoc """
  Collection of field candidates with helper functions for organizing and processing them.
  """

  alias Ecto.Relation.Inference.FieldCandidate

  defstruct candidates: []

  @type t :: %__MODULE__{
          candidates: [FieldCandidate.t()]
        }

  @doc """
  Creates a new FieldCandidates collection.
  """
  @spec new([FieldCandidate.t()]) :: t()
  def new(candidates \\ []) do
    %__MODULE__{candidates: candidates}
  end

  @doc """
  Adds a field candidate to the collection.
  """
  @spec add(t(), FieldCandidate.t()) :: t()
  def add(
        %__MODULE__{candidates: candidates} = collection,
        %FieldCandidate{} = candidate
      ) do
    %{collection | candidates: candidates ++ [candidate]}
  end

  @doc """
  Filters candidates by placement type.
  """
  @spec by_placement(t(), atom()) :: [FieldCandidate.t()]
  def by_placement(%__MODULE__{candidates: candidates}, placement) do
    Enum.filter(candidates, &(&1.placement == placement))
  end

  @doc """
  Filters candidates by category.
  """
  @spec by_category(t(), atom()) :: [FieldCandidate.t()]
  def by_category(%__MODULE__{candidates: candidates}, category) do
    Enum.filter(candidates, &(&1.category == category))
  end

  @doc """
  Gets all field definitions that should be generated.
  """
  @spec field_definitions(t()) :: [FieldCandidate.t()]
  def field_definitions(collection) do
    by_placement(collection, :field_definition)
  end

  @doc """
  Gets primary key fields that need @primary_key attribute.
  """
  @spec primary_key_attributes(t()) :: [FieldCandidate.t()]
  def primary_key_attributes(collection) do
    by_placement(collection, :attribute)
  end

  @doc """
  Gets composite primary key fields.
  """
  @spec composite_primary_key_fields(t()) :: [FieldCandidate.t()]
  def composite_primary_key_fields(collection) do
    by_category(collection, :composite_primary_key)
  end

  @doc """
  Checks if timestamps() macro should be used.
  """
  @spec has_timestamps?(t()) :: boolean()
  def has_timestamps?(collection) do
    timestamp_candidates = by_placement(collection, :timestamps_macro)

    has_inserted_at = Enum.any?(timestamp_candidates, &(&1.field.name == :inserted_at))
    has_updated_at = Enum.any?(timestamp_candidates, &(&1.field.name == :updated_at))

    has_inserted_at and has_updated_at
  end

  @doc """
  Gets foreign key type for @foreign_key_type attribute.
  """
  @spec foreign_key_type(t()) :: atom() | nil
  def foreign_key_type(collection) do
    fk_candidates = by_category(collection, :foreign_key)

    # Check if there are any binary_id or Ecto.UUID foreign key fields
    has_binary_id_fks =
      Enum.any?(fk_candidates, fn candidate ->
        candidate.field.ecto_type in [:binary_id, Ecto.UUID]
      end)

    if has_binary_id_fks, do: :binary_id, else: nil
  end
end
