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

  defimpl Inspect do
    def inspect(%Drops.Relation.Schema.Field{} = field, _opts) do
      "#Field<#{field.name}: #{inspect(field.type)}>"
    end
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

    # Right field takes precedence for all other properties
    %__MODULE__{
      name: right.name,
      type: right.type,
      meta: merged_meta
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

defimpl Drops.Relation.Inference.SchemaFieldAST, for: Drops.Relation.Schema.Field do
  @moduledoc """
  Default implementation of SchemaFieldAST protocol for Field structs.

  This implementation provides the default behavior for generating Ecto schema
  AST from Field structs, handling common cases like regular fields, primary keys,
  foreign keys, and parameterized types.
  """

  @doc """
  Generates field definition AST for a Field struct.

  This function handles the conversion of a Field struct to the appropriate
  `field(...)` AST, including handling of options like source mapping and
  parameterized types.
  """
  def to_field_ast(%Drops.Relation.Schema.Field{} = field) do
    to_field_ast_with_category(field, :regular)
  end

  @doc """
  Generates field definition AST for a Field struct with category information.

  This function handles the conversion of a Field struct to the appropriate
  `field(...)` AST, taking into account the field's category in the schema.
  """
  def to_field_ast_with_category(%Drops.Relation.Schema.Field{} = field, category) do
    # Handle parameterized types by extracting options
    {type, type_opts} = extract_type_and_options(field.type)

    base_opts = if field.source != field.name, do: [source: field.source], else: []

    # Add primary_key: true for composite primary key fields
    pk_opts = if category == :composite_primary_key, do: [primary_key: true], else: []

    all_opts = Keyword.merge(type_opts, base_opts) |> Keyword.merge(pk_opts)

    if all_opts == [] do
      quote do
        Ecto.Schema.field(unquote(field.name), unquote(type))
      end
    else
      quote do
        Ecto.Schema.field(unquote(field.name), unquote(type), unquote(all_opts))
      end
    end
  end

  @doc """
  Generates attribute AST for a Field struct.

  This function determines if a field needs a special attribute (like @primary_key)
  and generates the appropriate AST. Returns nil for fields that don't need attributes.

  This function is called by the Inference module for fields that have placement: :attribute,
  which means they need to generate an attribute rather than a field definition.
  """
  def to_attribute_ast(%Drops.Relation.Schema.Field{} = field) do
    # Get boolean values from metadata
    is_foreign_key = Map.get(field.meta, :foreign_key, false)
    is_primary_key = Map.get(field.meta, :primary_key, false)

    cond do
      # Check if this is explicitly marked as a foreign key field in metadata
      is_foreign_key and field.type in [:binary_id, Ecto.UUID] ->
        quote do
          @foreign_key_type :binary_id
        end

      # Check if this is explicitly marked as a primary key field in metadata
      is_primary_key and field.type == Ecto.UUID ->
        quote do
          @primary_key {unquote(field.name), Ecto.UUID, autogenerate: true}
        end

      # Check if this is explicitly marked as a primary key field in metadata
      is_primary_key and field.type == :binary_id ->
        quote do
          @primary_key {unquote(field.name), :binary_id, autogenerate: true}
        end

      # Check if this is explicitly marked as a primary key field with custom type
      is_primary_key and field.type not in [:id, :integer] ->
        quote do
          @primary_key {unquote(field.name), unquote(field.type), autogenerate: true}
        end

      true ->
        # Default case - no attribute needed
        # We rely purely on metadata and do not infer based on field names
        nil
    end
  end

  # Helper function to extract type and options from type for field generation
  defp extract_type_and_options(type) do
    case type do
      {type, opts} when is_list(opts) ->
        {type, opts}

      {type, opts} when is_map(opts) ->
        {type, Map.to_list(opts)}

      type ->
        {type, []}
    end
  end
end
