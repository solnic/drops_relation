defmodule Ecto.Relation.Schema.Indices do
  @moduledoc """
  Container for all indices on a database table/schema.

  This struct holds a collection of Index structs and provides utility
  functions for working with multiple indices.

  ## Examples

      indices = Ecto.Relation.Schema.Indices.new([
        Ecto.Relation.Schema.Index.new("users_email_index", [:email], true),
        Ecto.Relation.Schema.Index.new("users_name_index", [:name], false)
      ])
  """

  alias Ecto.Relation.Schema.Index

  @type t :: %__MODULE__{
          indices: [Index.t()]
        }

  alias Ecto.Relation.Schema.Serializable
  use Serializable

  defstruct indices: []

  @doc """
  Creates a new Indices struct.

  ## Parameters

  - `indices` - List of Index structs

  ## Examples

      iex> indices = [
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true),
      ...>   Ecto.Relation.Schema.Index.new("name_idx", [:name], false)
      ...> ]
      iex> Ecto.Relation.Schema.Indices.new(indices)
      %Ecto.Relation.Schema.Indices{indices: [...]}
  """
  @spec new([Index.t()]) :: t()
  def new(indices \\ []) when is_list(indices) do
    %__MODULE__{indices: indices}
  end

  @doc """
  Adds an index to the collection.

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new()
      iex> index = Ecto.Relation.Schema.Index.new("email_idx", [:email], true)
      iex> Ecto.Relation.Schema.Indices.add_index(indices, index)
      %Ecto.Relation.Schema.Indices{indices: [%Ecto.Relation.Schema.Index{...}]}
  """
  @spec add_index(t(), Index.t()) :: t()
  def add_index(%__MODULE__{indices: indices} = container, %Index{} = index) do
    %{container | indices: [index | indices]}
  end

  @doc """
  Finds all indices that cover a specific field.

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new([
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true),
      ...>   Ecto.Relation.Schema.Index.new("name_email_idx", [:name, :email], false)
      ...> ])
      iex> Ecto.Relation.Schema.Indices.find_by_field(indices, :email)
      [%Ecto.Relation.Schema.Index{name: "email_idx", ...}, ...]
  """
  @spec find_by_field(t(), atom()) :: [Index.t()]
  def find_by_field(%__MODULE__{indices: indices}, field) do
    Enum.filter(indices, &Index.covers_field?(&1, field))
  end

  @doc """
  Finds all unique indices.

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new([
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true),
      ...>   Ecto.Relation.Schema.Index.new("name_idx", [:name], false)
      ...> ])
      iex> Ecto.Relation.Schema.Indices.unique_indices(indices)
      [%Ecto.Relation.Schema.Index{name: "email_idx", unique: true, ...}]
  """
  @spec unique_indices(t()) :: [Index.t()]
  def unique_indices(%__MODULE__{indices: indices}) do
    Enum.filter(indices, & &1.unique)
  end

  @doc """
  Finds all composite indices (covering multiple fields).

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new([
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true),
      ...>   Ecto.Relation.Schema.Index.new("name_email_idx", [:name, :email], false)
      ...> ])
      iex> Ecto.Relation.Schema.Indices.composite_indices(indices)
      [%Ecto.Relation.Schema.Index{name: "name_email_idx", fields: [:name, :email], ...}]
  """
  @spec composite_indices(t()) :: [Index.t()]
  def composite_indices(%__MODULE__{indices: indices}) do
    Enum.filter(indices, &Index.composite?/1)
  end

  @doc """
  Checks if there are any indices in the collection.

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new()
      iex> Ecto.Relation.Schema.Indices.empty?(indices)
      true

      iex> indices = Ecto.Relation.Schema.Indices.new([
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true)
      ...> ])
      iex> Ecto.Relation.Schema.Indices.empty?(indices)
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{indices: indices}) do
    indices == []
  end

  defimpl Inspect do
    def inspect(%Ecto.Relation.Schema.Indices{} = indices, _opts) do
      count = length(indices.indices)
      unique_count = indices.indices |> Enum.count(& &1.unique)

      "#Indices<#{count} total, #{unique_count} unique>"
    end
  end

  @doc """
  Returns the number of indices in the collection.

  ## Examples

      iex> indices = Ecto.Relation.Schema.Indices.new([
      ...>   Ecto.Relation.Schema.Index.new("email_idx", [:email], true),
      ...>   Ecto.Relation.Schema.Index.new("name_idx", [:name], false)
      ...> ])
      iex> Ecto.Relation.Schema.Indices.count(indices)
      2
  """
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{indices: indices}) do
    length(indices)
  end
end
