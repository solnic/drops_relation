defmodule Drops.Relation.Inference do
  alias Drops.Relation.SQL
  alias Drops.Relation.Schema.Field
  alias Drops.Relation.Inference.FieldCandidate
  alias Drops.Relation.Inference.FieldCandidates
  alias Drops.Relation.Inference.SchemaFieldAST

  @doc """
  Builds field candidates from inferred schema, associations, and custom fields.
  """
  @spec build_field_candidates(
          Drops.Relation.Schema.t(),
          list(),
          list()
        ) :: FieldCandidates.t()
  def build_field_candidates(drops_relation_schema, association_definitions, custom_fields) do
    # Get primary key field names
    primary_key_names = Enum.map(drops_relation_schema.primary_key.fields, & &1.name)

    # Check if this is a composite primary key
    is_composite_pk = length(primary_key_names) > 1

    # Get field names that should be excluded due to associations
    association_field_names = extract_association_field_names(association_definitions)

    # Get field names that are foreign keys based on associations
    foreign_key_field_names = extract_foreign_key_field_names(association_definitions)

    # Process custom fields into Field structs
    custom_field_structs = process_custom_fields(custom_fields)
    custom_field_map = Map.new(custom_field_structs, &{&1.name, &1})

    # Start with empty collection
    candidates = FieldCandidates.new()

    # Process inferred fields
    candidates =
      Enum.reduce(drops_relation_schema.fields, candidates, fn inferred_field, acc ->
        # Check if this field has a custom override
        case Map.get(custom_field_map, inferred_field.name) do
          nil ->
            # Pure inferred field
            is_association_fk = inferred_field.name in association_field_names

            # Check if this field is a foreign key based on associations
            is_foreign_key = inferred_field.name in foreign_key_field_names

            category =
              FieldCandidate.categorize_field(
                inferred_field,
                primary_key_names,
                is_association_fk,
                is_composite_pk,
                is_foreign_key
              )

            candidate = FieldCandidate.new(inferred_field, :inferred, category)

            FieldCandidates.add(acc, candidate)

          custom_field ->
            # Merged field (inferred + custom)
            merged_field = Field.merge(inferred_field, custom_field)
            is_association_fk = merged_field.name in association_field_names

            category =
              FieldCandidate.categorize_field(
                merged_field,
                primary_key_names,
                is_association_fk,
                is_composite_pk
              )

            candidate = FieldCandidate.new(merged_field, :merged, category)
            FieldCandidates.add(acc, candidate)
        end
      end)

    # Add any custom fields that don't have corresponding inferred fields
    inferred_field_names = MapSet.new(drops_relation_schema.fields, & &1.name)

    additional_custom_fields =
      Enum.reject(custom_field_structs, fn field ->
        MapSet.member?(inferred_field_names, field.name)
      end)

    Enum.reduce(additional_custom_fields, candidates, fn custom_field, acc ->
      is_association_fk = custom_field.name in association_field_names

      category =
        FieldCandidate.categorize_field(
          custom_field,
          primary_key_names,
          is_association_fk,
          is_composite_pk
        )

      candidate = FieldCandidate.new(custom_field, :custom, category)
      FieldCandidates.add(acc, candidate)
    end)
  end

  @doc """
  Generates Ecto schema AST from field candidates.
  """
  @spec generate_schema_ast_from_candidates(
          Drops.Relation.Schema.t(),
          list(),
          list(),
          String.t()
        ) :: Macro.t()
  def generate_schema_ast_from_candidates(
        drops_relation_schema,
        association_definitions,
        custom_fields,
        table_name
      ) do
    # Build field candidates
    candidates =
      build_field_candidates(drops_relation_schema, association_definitions, custom_fields)

    # Generate field definitions from candidates that should be field() calls
    # Sort by the original field order from the drops_relation_schema to maintain consistent ordering
    field_definitions =
      candidates
      |> FieldCandidates.field_definitions()
      |> Enum.sort_by(fn candidate ->
        # Find the index of this field in the original schema fields
        Enum.find_index(drops_relation_schema.fields, &(&1.name == candidate.field.name)) || 999
      end)
      |> Enum.map(&generate_field_definition_from_candidate/1)

    # Add timestamps() macro if needed
    all_field_definitions =
      if FieldCandidates.has_timestamps?(candidates) do
        field_definitions ++ [quote(do: timestamps())]
      else
        field_definitions
      end

    # Generate @primary_key attribute if needed
    primary_key_attr =
      generate_primary_key_attribute_from_candidates(candidates, drops_relation_schema.primary_key)

    # Generate @foreign_key_type attribute if needed
    foreign_key_type_attr =
      generate_foreign_key_type_attribute_from_candidates(candidates)

    # Create the final schema AST with attributes
    schema_ast =
      quote location: :keep do
        schema unquote(table_name) do
          (unquote_splicing(all_field_definitions))

          unquote(association_definitions)
        end
      end

    # Combine attributes with schema
    attributes = []

    attributes =
      if primary_key_attr != nil do
        [primary_key_attr | attributes]
      else
        attributes
      end

    attributes =
      if foreign_key_type_attr != nil do
        [foreign_key_type_attr | attributes]
      else
        attributes
      end

    if length(attributes) > 0 do
      quote location: :keep do
        (unquote_splicing(Enum.reverse(attributes)))
        unquote(schema_ast)
      end
    else
      schema_ast
    end
  end

  @doc """
  Generates a field definition AST from a field candidate.
  """
  @spec generate_field_definition_from_candidate(FieldCandidate.t()) :: Macro.t()
  def generate_field_definition_from_candidate(%FieldCandidate{
        field: field,
        category: category
      }) do
    # Use the protocol to generate the field AST with category information
    SchemaFieldAST.to_field_ast_with_category(field, category)
  end

  @doc """
  Generates @primary_key attribute from field candidates.
  """
  @spec generate_primary_key_attribute_from_candidates(
          FieldCandidates.t(),
          Drops.Relation.Schema.PrimaryKey.t()
        ) :: Macro.t() | nil
  def generate_primary_key_attribute_from_candidates(candidates, _primary_key) do
    # Get primary key candidates that need @primary_key attribute (single custom PKs)
    pk_attribute_candidates = FieldCandidates.primary_key_attributes(candidates)

    # Get composite primary key candidates
    composite_pk_candidates = FieldCandidates.composite_primary_key_fields(candidates)

    cond do
      length(composite_pk_candidates) > 0 ->
        # Composite primary key - use @primary_key false (fields have primary_key: true)
        quote do
          @primary_key false
        end

      length(pk_attribute_candidates) == 1 ->
        # Single field primary key - use protocol to generate attribute
        [candidate] = pk_attribute_candidates
        field = candidate.field

        SchemaFieldAST.to_attribute_ast(field)

      true ->
        # No custom primary key attribute needed
        nil
    end
  end

  @doc """
  Generates @foreign_key_type attribute from field candidates.
  """
  @spec generate_foreign_key_type_attribute_from_candidates(FieldCandidates.t()) ::
          Macro.t() | nil
  def generate_foreign_key_type_attribute_from_candidates(candidates) do
    # Check if any field candidates can generate a foreign_key_type attribute via protocol
    fk_candidates = FieldCandidates.by_category(candidates, :foreign_key)

    # Try to get foreign key type attribute from protocol
    protocol_attributes =
      fk_candidates
      |> Enum.map(fn candidate -> SchemaFieldAST.to_attribute_ast(candidate.field) end)
      |> Enum.reject(&is_nil/1)

    case protocol_attributes do
      [attribute | _] ->
        # Use the first non-nil attribute from protocol
        attribute

      [] ->
        # Fallback to original logic
        case FieldCandidates.foreign_key_type(candidates) do
          :binary_id ->
            quote do
              @foreign_key_type :binary_id
            end

          _ ->
            nil
        end
    end
  end

  def infer_schema(relation, name, repo) do
    # Use the unified schema inference implementation
    drops_relation_schema = SQL.Inference.infer_from_table(name, repo)

    # Get optional Ecto associations definitions AST
    association_definitions = Module.get_attribute(relation, :associations, [])

    # Generate the Ecto schema AST using the new field candidate approach
    ecto_schema_ast =
      generate_schema_ast_from_candidates(
        drops_relation_schema,
        association_definitions,
        # No custom fields for this function
        [],
        name
      )

    {ecto_schema_ast, drops_relation_schema}
  end

  # Simplified custom field processing using Macro.expand on each field element
  defp process_custom_fields(custom_fields) do
    expanded_fields = Enum.map(custom_fields, &Macro.expand(&1, __ENV__))

    Enum.map(expanded_fields, fn {name, type, opts} ->
      source = Keyword.get(opts, :source, name)

      meta = %{
        nullable: Keyword.get(opts, :null),
        default: Keyword.get(opts, :default),
        check_constraints: []
      }

      ecto_type = build_ecto_type(type, opts)
      normalized_type = normalize_type(ecto_type)

      Field.new(name, normalized_type, ecto_type, source, meta)
    end)
  end

  # Simplified ecto_type building (now works with expanded types)
  defp build_ecto_type(type, opts) do
    if length(opts) > 0, do: {type, opts}, else: type
  end

  # Simplified type normalization
  defp normalize_type(type) do
    case type do
      :string ->
        :string

      :integer ->
        :integer

      :boolean ->
        :boolean

      :float ->
        :float

      :decimal ->
        :decimal

      :date ->
        :date

      :time ->
        :time

      :naive_datetime ->
        :naive_datetime

      :utc_datetime ->
        :utc_datetime

      :binary ->
        :binary

      :id ->
        :integer

      :binary_id ->
        :binary

      # Default for parameterized types
      {module, _opts} when is_atom(module) ->
        :string

      {container, inner_type} when is_atom(container) ->
        {container, normalize_type(inner_type)}

      # Default fallback
      _ ->
        :string
    end
  end

  # Helper function to extract foreign key field names from association definitions
  # that should be excluded from inferred schema. For belongs_to associations,
  # Ecto automatically creates the foreign key field UNLESS define_field: false
  # is specified, in which case the user is responsible for defining the field.
  defp extract_association_field_names(association_definitions) do
    case association_definitions do
      # Handle single belongs_to association with options
      {:belongs_to, _meta, [field_name, _related_module, opts]} when is_list(opts) ->
        # Only exclude the foreign key field if define_field is NOT false
        # (i.e., when Ecto will create it automatically)
        if Keyword.get(opts, :define_field, true) == false do
          # User specified define_field: false, so they'll define the field themselves
          # Don't exclude it from inferred schema
          []
        else
          # Ecto will create the field automatically, so exclude it from inferred schema
          [infer_foreign_key_field_name(field_name, opts)]
        end

      {:belongs_to, _meta, [field_name, _related_module]} ->
        # No define_field option specified, defaults to true, so Ecto will create the field
        [infer_foreign_key_field_name(field_name, [])]

      # Handle block with multiple associations
      {:__block__, _meta, associations} when is_list(associations) ->
        Enum.flat_map(associations, &extract_association_field_names/1)

      # Handle other association types (has_many, many_to_many, etc.)
      {assoc_type, _meta, _args} when assoc_type in [:has_many, :has_one, :many_to_many] ->
        # These don't create foreign key fields in the current table
        []

      # Handle any other case
      _ ->
        []
    end
  end

  # Helper function to extract ALL foreign key field names from association definitions
  # This is used for categorization, regardless of define_field option
  defp extract_foreign_key_field_names(association_definitions) do
    case association_definitions do
      # Handle single belongs_to association with options
      {:belongs_to, _meta, [field_name, _related_module, opts]} when is_list(opts) ->
        # Always include foreign key fields for categorization
        [infer_foreign_key_field_name(field_name, opts)]

      {:belongs_to, _meta, [field_name, _related_module]} ->
        # Always include foreign key fields for categorization
        [infer_foreign_key_field_name(field_name, [])]

      # Handle block with multiple associations
      {:__block__, _meta, associations} when is_list(associations) ->
        Enum.flat_map(associations, &extract_foreign_key_field_names/1)

      # Handle other association types (has_many, many_to_many, etc.)
      {assoc_type, _meta, _args} when assoc_type in [:has_many, :has_one, :many_to_many] ->
        # These don't create foreign key fields in the current table
        []

      # Handle any other case
      _ ->
        []
    end
  end

  # Helper function to infer the foreign key field name from association name and options
  defp infer_foreign_key_field_name(association_name, opts) do
    case Keyword.get(opts, :foreign_key) do
      nil ->
        # Default foreign key naming: association_name + "_id"
        String.to_atom("#{association_name}_id")

      foreign_key when is_atom(foreign_key) ->
        foreign_key
    end
  end
end
