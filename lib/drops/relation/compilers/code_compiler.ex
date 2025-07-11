defmodule Drops.Relation.Compilers.CodeCompiler do
  @moduledoc """
  Compiler for converting Drops.Relation.Schema structures to Ecto schema AST.

  This module follows the same visitor pattern as Drops.SQL.Compiler and
  Drops.Relation.Compilers.SchemaCompiler but works with Drops.Relation.Schema structs
  and converts them to quoted expressions for field definitions and attributes.

  Since primary key nodes now contain complete field information, field nodes
  with primary_key: true are skipped and handled entirely by primary key processing.

  ## Usage

      # Convert a Relation Schema to field AST
      schema = %Drops.Relation.Schema{...}
      field_asts = Drops.Relation.Compilers.CodeCompiler.visit(schema, [])

  ## Examples

      iex> schema = %Drops.Relation.Schema{fields: [...], primary_key: ...}
      iex> asts = Drops.Relation.Compilers.CodeCompiler.visit(schema, [])
      iex> is_list(asts)
      true
  """

  alias Drops.Relation.Schema

  @doc """
  Main entry point for converting Relation Schema to structured compilation output.

  ## Parameters

  - `schema` - A Drops.Relation.Schema struct
  - `opts` - Optional compilation options
    - `:grouped` - If true, returns structured map; if false, returns flat list (default: false for backward compatibility)

  ## Returns

  When `:grouped` is true, returns a map with:
  ```
  %{
    attributes: %{
      primary_key: [...],      # @primary_key definitions
      foreign_key_type: [...], # @foreign_key_type definitions
      other: [...]             # Other @ attributes
    },
    field_definitions: [...],  # field() calls
    schema_options: [...]      # Any schema-level options
  }
  ```

  When `:grouped` is false (default), returns a flat list of quoted expressions for backward compatibility.

  ## Examples

      iex> schema = %Drops.Relation.Schema{fields: [...], ...}
      iex> asts = Drops.Relation.Compilers.CodeCompiler.visit(schema, [])
      iex> is_list(asts)
      true

      iex> grouped = Drops.Relation.Compilers.CodeCompiler.visit(schema, grouped: true)
      iex> is_map(grouped) and Map.has_key?(grouped, :attributes)
      true
  """
  def visit(%Schema{} = schema, opts) do
    # Process schema using Enumerable protocol to get tuple representation
    # but keep the original schema in opts for field processing
    new_opts = Keyword.put(opts, :schema, schema)

    schema_tuple =
      schema
      |> Enum.to_list()
      # Get the {:schema, components} tuple
      |> List.first()

    result = visit(schema_tuple, new_opts)

    # Return grouped or flat result based on options
    if opts[:grouped] do
      group_compilation_result(result)
    else
      # Backward compatibility: return flat list
      result
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
    end
  end

  # Visit schema tuple structure
  def visit({:schema, components}, opts) do
    # Process each component type in the schema
    Enum.reduce(components, [], fn component, acc ->
      component_ast = visit(component, opts)
      [acc, component_ast]
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  # Visit primary key tuple structure - now handles both attributes and field definitions
  def visit({:primary_key, [_name, columns, meta]}, opts) when is_list(columns) do
    composite = Map.get(meta, :composite, false)
    schema = opts[:schema]

    case {length(columns), composite} do
      {0, _} ->
        nil

      {1, false} ->
        field_name = List.first(columns)
        field = Enum.find(schema.fields, &(&1.name == field_name))
        generate_single_primary_key_attribute(field)

      {_, true} ->
        pk_fields = Enum.filter(schema.fields, &(&1.name in columns))

        attribute =
          quote do
            @primary_key false
          end

        field_definitions = Enum.map(pk_fields, &generate_composite_primary_key_field/1)
        [attribute | field_definitions]
    end
  end

  # Visit field tuple structure - simplified to skip primary key fields
  def visit({:field, nodes}, opts) do
    [name, type_tuple, meta_tuple] = visit(nodes, opts)

    # Extract the actual type and meta from their tuples
    type = visit(type_tuple, opts)
    meta = visit(meta_tuple, opts)

    cond do
      # Skip timestamp fields - they're handled by timestamps() macro
      name in [:inserted_at, :updated_at] ->
        nil

      # Skip primary key fields - they're handled by primary key processing
      Map.get(meta, :primary_key, false) ->
        nil

      true ->
        # Generate regular field definition
        generate_field_definition(name, type, meta)
    end
  end

  # Visit type tuple structure
  def visit({:type, type}, _opts) when is_atom(type) do
    type
  end

  def visit({:type, {type_module, type_opts}}, _opts) do
    {type_module, type_opts}
  end

  # Visit meta tuple structure
  def visit({:meta, meta}, _opts) when is_map(meta) do
    meta
  end

  # Visit foreign key tuple structure
  def visit(
        {:foreign_key, [_field, _references_table, _references_field, _association_name]},
        _opts
      ) do
    # For now, foreign keys don't generate AST directly in field definitions
    # They would be handled by association generation in a separate phase
    nil
  end

  # Visit index tuple structure
  def visit({:index, [_name, _columns, _unique, _type]}, _opts) do
    # Indices don't generate AST in schema field definitions
    # They would be handled by migration generation
    nil
  end

  # Visit source tuple (from schema components)
  def visit({:source, _source}, _opts) do
    # Source is handled at the schema level, not in field definitions
    nil
  end

  # Visit foreign key attributes tuple (from schema components)
  def visit({:foreign_key_attributes, fields}, _opts) when is_list(fields) do
    # Generate @foreign_key_type attribute if any field is a foreign key with special type
    Enum.find_value(fields, fn field ->
      is_foreign_key = Map.get(field.meta, :foreign_key, false)

      if is_foreign_key and field.type in [:binary_id, Ecto.UUID] do
        quote do
          @foreign_key_type :binary_id
        end
      else
        nil
      end
    end)
  end

  # Visit fields list (from schema components)
  def visit({:fields, field_tuples}, opts) when is_list(field_tuples) do
    field_tuples
    |> Enum.map(&visit(&1, opts))
    |> Enum.reject(&is_nil/1)
  end

  # Visit foreign_keys list (from schema components)
  def visit({:foreign_keys, fk_tuples}, opts) when is_list(fk_tuples) do
    fk_tuples
    |> Enum.map(&visit(&1, opts))
    |> Enum.reject(&is_nil/1)
  end

  # Visit indices list (from schema components)
  def visit({:indices, index_tuples}, opts) when is_list(index_tuples) do
    index_tuples
    |> Enum.map(&visit(&1, opts))
    |> Enum.reject(&is_nil/1)
  end

  # Visit parameterized type tuples (like {Ecto.UUID, []})
  def visit({type, type_opts}, _opts) when is_atom(type) and is_list(type_opts) do
    {type, type_opts}
  end

  def visit({type, type_opts}, _opts) when is_atom(type) and is_map(type_opts) do
    {type, Map.to_list(type_opts)}
  end

  # Visit atomic values (field names, types, etc.)
  def visit(value, _opts) when is_atom(value), do: value
  def visit(value, _opts) when is_binary(value), do: value
  def visit(value, _opts) when is_number(value), do: value

  # Visit enumerable structures recursively
  def visit(enumerable, opts) when is_map(enumerable) do
    # Process maps by visiting each key-value pair
    Enum.reduce(enumerable, %{}, fn {key, value}, acc ->
      visited_key = visit(key, opts)
      visited_value = visit(value, opts)
      Map.put(acc, visited_key, visited_value)
    end)
  end

  def visit(enumerable, opts) when is_list(enumerable) and not is_binary(enumerable) do
    # Process lists by visiting each element
    Enum.map(enumerable, &visit(&1, opts))
  end

  def visit(nil, _opts), do: nil

  # Fallback for other values
  def visit(value, _opts), do: value

  # Groups the flat compilation result into structured categories.
  # Returns a map with categorized compilation results.
  defp group_compilation_result(result) do
    flattened_result =
      result
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    # Separate attributes from field definitions
    {attributes, field_definitions} =
      Enum.split_with(flattened_result, fn ast ->
        case ast do
          {:@, _, _} -> true
          _ -> false
        end
      end)

    # Further categorize attributes by type
    categorized_attributes = categorize_attributes(attributes)

    %{
      attributes: categorized_attributes,
      field_definitions: field_definitions,
      # Reserved for future use
      schema_options: []
    }
  end

  # Categorizes attribute AST nodes by their type.
  # Returns a map with categorized attributes.
  defp categorize_attributes(attributes) do
    Enum.reduce(attributes, %{primary_key: [], foreign_key_type: [], other: []}, fn attr, acc ->
      case attr do
        {:@, _, [{:primary_key, _, _}]} ->
          Map.update!(acc, :primary_key, &[attr | &1])

        {:@, _, [{:foreign_key_type, _, _}]} ->
          Map.update!(acc, :foreign_key_type, &[attr | &1])

        _ ->
          Map.update!(acc, :other, &[attr | &1])
      end
    end)
    |> Enum.map(fn {key, value} -> {key, Enum.reverse(value)} end)
    |> Map.new()
  end

  # Helper function to generate single primary key attributes
  defp generate_single_primary_key_attribute(field) when is_nil(field) do
    nil
  end

  defp generate_single_primary_key_attribute(field) do
    is_foreign_key = Map.get(field.meta, :foreign_key, false)

    cond do
      is_foreign_key and field.type in [:binary_id, Ecto.UUID] ->
        quote do
          @foreign_key_type :binary_id
        end

      field.type == Ecto.UUID ->
        quote do
          @primary_key {unquote(field.name), Ecto.UUID, autogenerate: true}
        end

      field.type == :binary_id ->
        quote do
          @primary_key {unquote(field.name), :binary_id, autogenerate: true}
        end

      field.type not in [:id, :integer] ->
        quote do
          @primary_key {unquote(field.name), unquote(field.type), autogenerate: true}
        end

      true ->
        # Default :id or :integer type - no attribute needed, Ecto will use default
        nil
    end
  end

  # Helper function to generate composite primary key field definitions
  defp generate_composite_primary_key_field(field) do
    field_opts = [{:primary_key, true}]

    # Add source option if different from field name
    source = Map.get(field.meta, :source, field.name)
    field_opts = if source != field.name, do: [{:source, source} | field_opts], else: field_opts

    # Add default option if present (skip auto_increment)
    field_opts =
      case Map.get(field.meta, :default) do
        nil -> field_opts
        :auto_increment -> field_opts
        value -> [{:default, value} | field_opts]
      end

    # Extract type and options
    {field_type, type_opts} =
      case field.type do
        {type_module, opts} when is_list(opts) -> {type_module, opts}
        {type_module, opts} when is_map(opts) -> {type_module, Map.to_list(opts)}
        _ -> {field.type, []}
      end

    all_opts = type_opts ++ field_opts

    quote do
      field(unquote(field.name), unquote(field_type), unquote(all_opts))
    end
  end

  # Helper function to generate regular field definitions
  defp generate_field_definition(name, type, meta) do
    field_opts = []

    # Add source option if different from field name
    source = Map.get(meta, :source, name)
    field_opts = if source != name, do: [{:source, source} | field_opts], else: field_opts

    # Add default option if present (skip auto_increment)
    field_opts =
      case Map.get(meta, :default) do
        nil -> field_opts
        :auto_increment -> field_opts
        value -> [{:default, value} | field_opts]
      end

    # Extract type and options, handling parameterized types specially
    {field_type, type_opts} =
      case type do
        # Handle runtime parameterized types (from compiled Ecto schemas)
        {:parameterized, {type_module, type_config}} when is_map(type_config) ->
          # Extract the original type definition from the parameterized type
          # For Ecto.Enum, we need to get the values from the config
          case type_module do
            Ecto.Enum ->
              values = Map.get(type_config, :mappings, []) |> Keyword.keys()
              {type_module, [values: values]}

            _ ->
              # For other parameterized types, try to extract meaningful options
              {type_module, []}
          end

        # Handle tuple types with options
        {type_module, opts} when is_list(opts) ->
          {type_module, opts}

        {type_module, opts} when is_map(opts) ->
          {type_module, Map.to_list(opts)}

        # Handle simple types
        _ ->
          {type, []}
      end

    all_opts = type_opts ++ field_opts

    if all_opts == [] do
      quote do
        field(unquote(name), unquote(field_type))
      end
    else
      quote do
        field(unquote(name), unquote(field_type), unquote(all_opts))
      end
    end
  end
end
