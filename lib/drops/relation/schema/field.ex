defmodule Drops.Relation.Schema.Field do
  @moduledoc """
  Represents a field in a database table/schema.

  This struct stores comprehensive information about a database field including
  its name, type information, and source mapping.

  ## Examples

      # Simple field
      %Drops.Relation.Schema.Field{
        name: :email,
        type: :string
      }
  """

  @type meta :: %{
          type: term(),
          adapter: atom(),
          source: atom(),
          nullable: boolean() | nil,
          default: term() | nil,
          check_constraints: [String.t()] | nil,
          primary_key: boolean() | nil,
          foreign_key: boolean() | nil
        }

  @type t :: %__MODULE__{
          name: atom(),
          type: term(),
          meta: meta()
        }

  alias Drops.Relation.Schema.Serializable
  use Serializable

  defstruct [:name, :type, :source, :meta]

  @doc """
  Creates a new Field struct.

  ## Parameters

  - `name` - The field name as an atom
  - `type` - The normalized type (e.g., :string, :integer)
  - `type` - The original Ecto type
  - `source` - The source column name in the database
  - `meta` - Optional metadata map with nullable, default, check_constraints

  ## Examples

      iex> Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      %Drops.Relation.Schema.Field{
        name: :email,
        type: :string,
        type: :string,
        source: :email,
        meta: %{}
      }

      iex> meta = %{nullable: false, default: "active"}
      iex> Drops.Relation.Schema.Field.new(:status, :string, :string, :status, meta)
      %Drops.Relation.Schema.Field{
        name: :status,
        type: :string,
        type: :string,
        source: :status,
        meta: %{nullable: false, default: "active"}
      }
  """
  @spec new(atom(), atom(), meta()) :: t()
  def new(name, type, meta \\ %{}) do
    %__MODULE__{name: name, type: type, meta: meta}
  end

  def new(name, db_type, ecto_type, source, meta \\ %{}) do
    __MODULE__.new(name, ecto_type, Map.merge(%{source: source, type: db_type}, meta))
  end

  @doc """
  Merges two Field structs, with the right field taking precedence.

  This function is useful for combining inferred fields with custom fields,
  where custom fields should override inferred properties while preserving
  metadata from both sources.

  ## Parameters

  - `left` - The base field (typically inferred)
  - `right` - The field to merge (typically custom, takes precedence)

  ## Examples

      iex> inferred = Drops.Relation.Schema.Field.new(:email, :string, :string, :email, %{nullable: true})
      iex> custom = Drops.Relation.Schema.Field.new(:email, :string, {:parameterized, {Ecto.Enum, %{values: [:active, :inactive]}}}, :email)
      iex> merged = Drops.Relation.Schema.Field.merge(inferred, custom)
      iex> merged.type
      {:parameterized, {Ecto.Enum, %{values: [:active, :inactive]}}}
      iex> merged.meta.nullable
      true
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{name: name} = left, %__MODULE__{name: name} = right) do
    # Merge metadata, with right taking precedence for non-nil values
    merged_meta =
      Map.merge(left.meta || %{}, right.meta || %{}, fn _key, left_val, right_val ->
        if right_val != nil, do: right_val, else: left_val
      end)

    # Handle special case: if type changes to Ecto.Enum and there's an incompatible default,
    # remove the default to avoid Ecto validation errors, but only if the default comes from
    # the left (inferred) field, not from the right (custom) field
    final_meta =
      case {left.type, right.type} do
        # Handle both tuple format and parameterized format for Ecto.Enum
        {_left_type, {Ecto.Enum, _opts}} ->
          # When changing to Ecto.Enum, remove string defaults from left field only
          case {Map.get(left.meta, :default), Map.get(right.meta, :default)} do
            {left_default, nil} when is_binary(left_default) ->
              # Remove the incompatible default from left field
              Map.delete(merged_meta, :default)

            _ ->
              # Keep the default if it's from right field or not a string
              merged_meta
          end

        {_left_type, {:parameterized, {Ecto.Enum, _config}}} ->
          # When changing to parameterized Ecto.Enum, remove string defaults from left field only
          case {Map.get(left.meta, :default), Map.get(right.meta, :default)} do
            {left_default, nil} when is_binary(left_default) ->
              # Remove the incompatible default from left field
              Map.delete(merged_meta, :default)

            _ ->
              # Keep the default if it's from right field or not a string
              merged_meta
          end

        _ ->
          merged_meta
      end

    # Right field takes precedence for all other properties
    %__MODULE__{
      name: right.name,
      type: right.type,
      meta: final_meta
    }
  end

  def merge(%__MODULE__{name: left_name}, %__MODULE__{name: right_name}) do
    raise ArgumentError,
          "Cannot merge fields with different names: #{inspect(left_name)} and #{inspect(right_name)}"
  end

  @doc """
  Checks if two fields have the same name.

  ## Examples

      iex> field1 = Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> field2 = Drops.Relation.Schema.Field.new(:email, :text, :text, :email_address)
      iex> Drops.Relation.Schema.Field.same_name?(field1, field2)
      true
  """
  @spec same_name?(t(), t()) :: boolean()
  def same_name?(%__MODULE__{name: name1}, %__MODULE__{name: name2}) do
    name1 == name2
  end

  @doc """
  Checks if a field matches a given name.

  ## Examples

      iex> field = Drops.Relation.Schema.Field.new(:email, :string, :string, :email)
      iex> Drops.Relation.Schema.Field.matches_name?(field, :email)
      true

      iex> Drops.Relation.Schema.Field.matches_name?(field, :name)
      false
  """
  @spec matches_name?(t(), atom()) :: boolean()
  def matches_name?(%__MODULE__{name: field_name}, name) when is_atom(name) do
    field_name == name
  end
end

# Enumerable protocol implementation for Field
defimpl Enumerable, for: Drops.Relation.Schema.Field do
  @moduledoc """
  Enumerable protocol implementation for Drops.Relation.Schema.Field.

  Returns a tuple structure for compiler processing:
  `{:field, [name, {:type, type}, {:meta, meta}]}`

  This enables the compiler to process fields using pattern matching
  on tagged tuples following the visitor pattern.
  """

  def count(%Drops.Relation.Schema.Field{}) do
    {:ok, 1}
  end

  def member?(%Drops.Relation.Schema.Field{} = field, element) do
    tuple_representation = {:field, [field.name, {:type, field.type}, {:meta, field.meta}]}
    {:ok, element == tuple_representation}
  end

  def slice(%Drops.Relation.Schema.Field{} = field) do
    tuple_representation = {:field, [field.name, {:type, field.type}, {:meta, field.meta}]}

    {:ok, 1,
     fn
       0, 1, _step -> [tuple_representation]
       _, _, _ -> []
     end}
  end

  def reduce(%Drops.Relation.Schema.Field{} = field, acc, fun) do
    tuple_representation = {:field, [field.name, {:type, field.type}, {:meta, field.meta}]}
    Enumerable.reduce([tuple_representation], acc, fun)
  end
end
