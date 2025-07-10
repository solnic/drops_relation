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

  def new(attributes) when is_map(attributes), do: struct(__MODULE__, attributes)

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

  defimpl Inspect do
    def inspect(%Drops.Relation.Schema{} = schema, _opts) do
      fields_summary =
        schema.fields
        |> Enum.map(fn field -> "#{field.name}: #{inspect(field.type)}" end)
        |> Enum.join(", ")

      pk_summary =
        case schema.primary_key do
          nil ->
            "[]"

          %{fields: []} ->
            "[]"

          %{fields: fields} ->
            field_names =
              fields
              |> Enum.map(& &1.name)
              |> Enum.join(", ")

            "[#{field_names}]"
        end

      fk_summary =
        case schema.foreign_keys do
          [] ->
            "[]"

          fks ->
            fk_list =
              fks
              |> Enum.map(fn fk ->
                "#{fk.field} -> #{fk.references_table}.#{fk.references_field}"
              end)
              |> Enum.join(", ")

            "[#{fk_list}]"
        end

      indices_summary =
        case schema.indices.indices do
          [] ->
            "[]"

          indices ->
            indices_list =
              indices
              |> Enum.map(&inspect/1)
              |> Enum.join(", ")

            "[#{indices_list}]"
        end

      "#Drops.Relation.Schema<" <>
        "source: #{inspect(schema.source)}, " <>
        "fields: [#{fields_summary}], " <>
        "primary_key: #{pk_summary}, " <>
        "foreign_keys: #{fk_summary}, " <>
        "indices: #{indices_summary}>"
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

  @doc """
  Checks if a field is a primary key field.

  ## Examples

      iex> Drops.Relation.Schema.primary_key_field?(schema, :id)
      true
  """
  @spec primary_key_field?(t(), atom()) :: boolean()
  def primary_key_field?(%__MODULE__{primary_key: primary_key}, field_name)
      when is_atom(field_name) do
    field_name in PrimaryKey.field_names(primary_key)
  end

  @doc """
  Checks if a field is a foreign key field.

  ## Examples

      iex> Drops.Relation.Schema.foreign_key_field?(schema, :user_id)
      true
  """
  @spec foreign_key_field?(t(), atom()) :: boolean()
  def foreign_key_field?(%__MODULE__{foreign_keys: foreign_keys}, field_name)
      when is_atom(field_name) do
    Enum.any?(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Gets the foreign key information for a specific field.

  ## Examples

      iex> fk = Drops.Relation.Schema.get_foreign_key(schema, :user_id)
      iex> fk.references_table
      "users"
  """
  @spec get_foreign_key(t(), atom()) :: ForeignKey.t() | nil
  def get_foreign_key(%__MODULE__{foreign_keys: foreign_keys}, field_name)
      when is_atom(field_name) do
    Enum.find(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Checks if the schema has a composite primary key.

  ## Examples

      iex> Drops.Relation.Schema.composite_primary_key?(schema)
      false
  """
  @spec composite_primary_key?(t()) :: boolean()
  def composite_primary_key?(%__MODULE__{primary_key: primary_key}) do
    PrimaryKey.composite?(primary_key)
  end

  @doc """
  Gets all field names in the schema.

  ## Examples

      iex> Drops.Relation.Schema.field_names(schema)
      [:id, :name, :email, :created_at, :updated_at]
  """
  @spec field_names(t()) :: [atom()]
  def field_names(%__MODULE__{fields: fields}) do
    Enum.map(fields, & &1.name)
  end

  @doc """
  Gets all foreign key field names in the schema.

  ## Examples

      iex> Drops.Relation.Schema.foreign_key_field_names(schema)
      [:user_id, :category_id]
  """
  @spec foreign_key_field_names(t()) :: [atom()]
  def foreign_key_field_names(%__MODULE__{foreign_keys: foreign_keys}) do
    Enum.map(foreign_keys, & &1.field)
  end

  @doc """
  Gets the source table name for the schema.

  ## Examples

      iex> Drops.Relation.Schema.source_table(schema)
      "users"
  """
  @spec source_table(t()) :: String.t()
  def source_table(%__MODULE__{source: source}) do
    source
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
    pk_field_count =
      if schema.primary_key && schema.primary_key.fields do
        length(schema.primary_key.fields)
      else
        0
      end

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

    # Add fields with enhanced meta containing primary key count
    enhanced_fields = enhance_fields_with_pk_count(schema.fields, pk_field_count)
    components = components ++ safe_flat_map(enhanced_fields)

    # Add indices
    components = components ++ safe_flat_map(get_indices(schema))

    components
  end

  # Helper to safely convert to list, handling nil values
  defp safe_to_list(nil), do: []
  defp safe_to_list(enumerable), do: Enum.to_list(enumerable) |> List.first()

  # Helper to safely flat_map, handling nil values
  defp safe_flat_map(nil), do: []
  defp safe_flat_map(list) when is_list(list), do: Enum.flat_map(list, &safe_to_list_unwrapped/1)

  # Helper to get the tuple representation without extra wrapping
  defp safe_to_list_unwrapped(nil), do: []
  defp safe_to_list_unwrapped(enumerable), do: Enum.to_list(enumerable)

  # Helper to get indices, handling nil values
  defp get_indices(%{indices: nil}), do: []
  defp get_indices(%{indices: %{indices: indices}}), do: indices
  defp get_indices(_), do: []

  # Helper to enhance fields with primary key count in their meta
  defp enhance_fields_with_pk_count(fields, pk_field_count) do
    Enum.map(fields, fn field ->
      enhanced_meta = Map.put(field.meta, :primary_key_count, pk_field_count)
      %{field | meta: enhanced_meta}
    end)
  end
end
