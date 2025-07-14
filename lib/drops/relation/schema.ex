defmodule Drops.Relation.Schema do
  @moduledoc """
  Represents comprehensive schema metadata for a database table/relation.

  This struct stores all extracted metadata about a database table including
  primary keys, foreign keys, field information, and indices. It serves as
  a central container for schema information that can be used for validation,
  documentation, and code generation.

  ## Examples

      # Create a schema with metadata
      schema = %Drops.Relation.Schema{
        source: "users",
        primary_key: %Drops.Relation.Schema.PrimaryKey{fields: [:id]},
        foreign_keys: [],
        fields: [
          %{name: :id, type: :integer, type: :id, source: :id},
          %{name: :email, type: :string, type: :string, source: :email}
        ],
        indices: %Drops.Relation.Schema.Indices{indices: [...]},
        associations: [
          # Ecto association structs (BelongsTo, Has, ManyToMany, etc.)
        ]
      }
  """

  alias Drops.Relation.Schema.{PrimaryKey, ForeignKey, Indices, Field}

  @type field_metadata :: %{
          name: atom(),
          type: atom(),
          type: term(),
          source: atom()
        }

  @type t :: %__MODULE__{
          source: String.t(),
          primary_key: PrimaryKey.t(),
          foreign_keys: [ForeignKey.t()],
          fields: [Field.t()],
          indices: Indices.t()
        }

  defstruct [
    :source,
    :primary_key,
    :foreign_keys,
    :fields,
    :indices
  ]

  alias Drops.Relation.Schema.Serializable

  use Serializable

  # defimpl JSON.Encoder do
  #   def encode(schema, opts) do
  #     JSON.Encoder.encode(
  #       Map.merge(
  #         %{
  #           __struct__: "Schema"
  #         },
  #         Map.from_struct(schema)
  #       ),
  #       opts
  #     )
  #   end
  # end

  @doc """
  Creates a new Schema struct with the provided metadata.

  ## Parameters

  - `source` - The table name
  - `primary_key` - Primary key information
  - `foreign_keys` - List of foreign key relationships
  - `fields` - List of field metadata
  - `indices` - Index information

  ## Examples

      iex> pk = Drops.Relation.Schema.PrimaryKey.new([:id])
      iex> indices = Drops.Relation.Schema.Indices.new([])
      iex> schema = Drops.Relation.Schema.new("users", pk, [], [], indices, [])
      iex> schema.source
      "users"
  """
  @spec new(
          String.t(),
          PrimaryKey.t(),
          [ForeignKey.t()],
          [Field.t()],
          Indices.t() | []
        ) :: t()
  def new(source, primary_key, foreign_keys, fields, indices) when is_list(indices) do
    new(source, primary_key, foreign_keys, fields, Indices.new(indices))
  end

  def new(source, primary_key, foreign_keys, fields, indices) do
    %__MODULE__{
      source: source,
      primary_key: primary_key,
      foreign_keys: foreign_keys,
      fields: fields,
      indices: indices
    }
  end

  def new(%{indices: indices} = attributes) when is_list(indices),
    do: new(Map.put(attributes, :indices, Indices.new(indices)))

  def new(attributes) when is_map(attributes) do
    # Ensure fields only contains Field structs
    cleaned_attributes =
      case Map.get(attributes, :fields) do
        fields when is_list(fields) ->
          cleaned_fields = Enum.filter(fields, &is_struct(&1, Field))
          Map.put(attributes, :fields, cleaned_fields)

        _ ->
          attributes
      end

    struct(__MODULE__, cleaned_attributes)
  end

  @spec empty(String.t()) :: t()
  def empty(name) do
    new(name, nil, [], [], [])
  end

  @doc """
  Merges two schemas, with the right schema taking precedence for conflicts.

  ## Parameters

  - `left` - The base schema
  - `right` - The schema to merge into the base, takes precedence

  ## Returns

  A merged Drops.Relation.Schema.t() struct.

  ## Examples

      iex> left = Drops.Relation.Schema.new("users", pk, [], [field1], [])
      iex> right = Drops.Relation.Schema.new("users", pk, [], [field2], [])
      iex> merged = Drops.Relation.Schema.merge(left, right)
      iex> length(merged.fields)
      2
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{source: source} = left, %__MODULE__{source: source} = right) do
    # Merge primary keys (right takes precedence if not nil)
    merged_primary_key =
      if right.primary_key != nil do
        PrimaryKey.merge(left.primary_key, right.primary_key)
      else
        left.primary_key
      end

    # Merge fields by name, with right taking precedence
    merged_fields = merge_fields(left.fields, right.fields)

    # Merge foreign keys (combine both lists, right takes precedence for same field names)
    merged_foreign_keys = merge_foreign_keys(left.foreign_keys, right.foreign_keys)

    # Merge indices (combine both lists)
    merged_indices = merge_indices(left.indices, right.indices)

    %__MODULE__{
      source: source,
      primary_key: merged_primary_key,
      foreign_keys: merged_foreign_keys,
      fields: merged_fields,
      indices: merged_indices
    }
  end

  def merge(%__MODULE__{source: left_source}, %__MODULE__{source: right_source}) do
    raise ArgumentError,
          "Cannot merge schemas with different sources: #{left_source} != #{right_source}"
  end

  # Merge fields by name, with right taking precedence
  defp merge_fields(left_fields, right_fields) do
    left_map = Map.new(left_fields, &{&1.name, &1})
    right_map = Map.new(right_fields, &{&1.name, &1})

    # Merge fields with same names, keep unique fields from both sides
    all_field_names =
      MapSet.union(MapSet.new(Map.keys(left_map)), MapSet.new(Map.keys(right_map)))

    Enum.map(all_field_names, fn field_name ->
      case {Map.get(left_map, field_name), Map.get(right_map, field_name)} do
        {left_field, nil} -> left_field
        {nil, right_field} -> right_field
        {left_field, right_field} -> Field.merge(left_field, right_field)
      end
    end)
  end

  # Merge foreign keys by field name, with right taking precedence
  defp merge_foreign_keys(left_fks, right_fks) do
    left_map = Map.new(left_fks, &{&1.field_name, &1})
    right_map = Map.new(right_fks, &{&1.field_name, &1})

    # Right takes precedence, then add any left FKs not in right
    Map.merge(left_map, right_map) |> Map.values()
  end

  # Merge indices (combine both lists for now)
  defp merge_indices(left_indices, right_indices) do
    alias Drops.Relation.Schema.Indices

    # For now, just combine the indices from both schemas
    # In a more sophisticated implementation, we might merge by name
    case {left_indices, right_indices} do
      {%Indices{indices: left_list}, %Indices{indices: right_list}} ->
        Indices.new(left_list ++ right_list)

      {left_list, right_list} when is_list(left_list) and is_list(right_list) ->
        Indices.new(left_list ++ right_list)

      {%Indices{} = left_indices, _} ->
        left_indices

      {left_indices, _} ->
        left_indices
    end
  end

  @doc """
  Finds a field by name in the schema.

  ## Examples

      iex> field = Drops.Relation.Schema.find_field(schema, :email)
      iex> field.name
      :email
  """
  @spec find_field(t(), atom()) :: Field.t() | nil
  def find_field(%__MODULE__{fields: fields}, field_name) when is_atom(field_name) do
    Enum.find(fields, &Field.matches_name?(&1, field_name))
  end

  # Access behavior implementation
  @behaviour Access

  @doc """
  Access behavior implementation for fetching fields by name.

  ## Examples

      iex> schema[:email]  # Returns the email field
      iex> schema[:id]     # Returns the id field
  """
  @impl Access
  def fetch(%__MODULE__{} = schema, key) when is_atom(key) do
    case find_field(schema, key) do
      nil -> :error
      field -> {:ok, field}
    end
  end

  def fetch(%__MODULE__{}, _key), do: :error

  @doc """
  Access behavior implementation for updating fields.

  ## Examples

      iex> get_and_update(schema, :email, fn field -> {field, %{field | type: :string}} end)
  """
  @impl Access
  def get_and_update(%__MODULE__{} = schema, key, function) when is_atom(key) do
    case find_field(schema, key) do
      nil ->
        {nil, schema}

      current_field ->
        case function.(current_field) do
          {get_value, new_field} ->
            updated_fields =
              Enum.map(schema.fields, fn field ->
                if field.name == key, do: new_field, else: field
              end)

            updated_schema = %{schema | fields: updated_fields}
            {get_value, updated_schema}

          :pop ->
            filtered_fields = Enum.reject(schema.fields, &(&1.name == key))
            updated_schema = %{schema | fields: filtered_fields}
            {current_field, updated_schema}
        end
    end
  end

  def get_and_update(%__MODULE__{} = schema, _key, _function) do
    {nil, schema}
  end

  @doc """
  Access behavior implementation for removing fields.

  ## Examples

      iex> pop(schema, :email)  # Removes and returns the email field
  """
  @impl Access
  def pop(%__MODULE__{} = schema, key) when is_atom(key) do
    case find_field(schema, key) do
      nil ->
        {nil, schema}

      field ->
        filtered_fields = Enum.reject(schema.fields, &(&1.name == key))
        updated_schema = %{schema | fields: filtered_fields}
        {field, updated_schema}
    end
  end

  def pop(%__MODULE__{} = schema, _key) do
    {nil, schema}
  end
end

# Enumerable protocol implementation for Schema
defimpl Enumerable, for: Drops.Relation.Schema do
  @moduledoc """
  Enumerable protocol implementation for Drops.Relation.Schema.

  Returns a tuple structure for compiler processing:
  `{:schema, list_of_its_components_dumped_via_to_list}`

  This enables the compiler to process schemas using pattern matching
  on tagged tuples following the visitor pattern.
  """

  def count(%Drops.Relation.Schema{}) do
    {:ok, 1}
  end

  def member?(%Drops.Relation.Schema{} = schema, element) do
    components = build_schema_components(schema)
    tuple_representation = {:schema, components}
    {:ok, element == tuple_representation}
  end

  def slice(%Drops.Relation.Schema{} = schema) do
    components = build_schema_components(schema)
    tuple_representation = {:schema, components}

    {:ok, 1,
     fn
       0, 1, _step -> [tuple_representation]
       _, _, _ -> []
     end}
  end

  def reduce(%Drops.Relation.Schema{} = schema, acc, fun) do
    components = build_schema_components(schema)
    tuple_representation = {:schema, components}
    Enumerable.reduce([tuple_representation], acc, fun)
  end

  # Helper function to build schema components list
  defp build_schema_components(schema) do
    components = []

    # Calculate primary key count for field meta enhancement
    # Add source
    components = components ++ [{:source, schema.source}]

    # Add primary key if present
    components =
      if schema.primary_key do
        components ++ [safe_to_list(schema.primary_key)]
      else
        components
      end

    # Add foreign key attributes (for @foreign_key_type generation)
    components = components ++ [{:foreign_key_attributes, schema.fields}]

    # Add foreign keys
    components = components ++ safe_flat_map(schema.foreign_keys)

    # Add fields
    components = components ++ safe_flat_map(schema.fields)

    # Add indices
    components = components ++ safe_flat_map(get_indices(schema))

    components
  end

  # Helper to safely convert to list, handling nil values
  defp safe_to_list(nil), do: []
  defp safe_to_list(enumerable), do: Enum.to_list(enumerable) |> List.first()

  # Helper to safely flat_map, handling nil values
  defp safe_flat_map(nil), do: []

  # Handle case where a PrimaryKey struct is passed instead of a list
  defp safe_flat_map(%Drops.Relation.Schema.PrimaryKey{}), do: []

  defp safe_flat_map(list) when is_list(list) do
    # Filter out any non-Field structs that might have ended up in the fields list
    filtered_list = Enum.filter(list, &is_struct(&1, Drops.Relation.Schema.Field))
    Enum.flat_map(filtered_list, &safe_to_list_unwrapped/1)
  end

  # Helper to get the tuple representation without extra wrapping
  defp safe_to_list_unwrapped(nil), do: []

  defp safe_to_list_unwrapped(enumerable) do
    # Enum.to_list returns a list with one tuple, flat_map expects a list
    # so we return the list as-is
    Enum.to_list(enumerable)
  end

  # Helper to get indices, handling nil values
  defp get_indices(%{indices: nil}), do: []
  defp get_indices(%{indices: %{indices: indices}}), do: indices
  defp get_indices(_), do: []
end
