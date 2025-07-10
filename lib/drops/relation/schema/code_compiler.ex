defmodule Drops.Relation.Schema.CodeCompiler do
  @moduledoc """
  Compiler for converting Drops.Relation.Schema structures to Ecto schema AST.

  This module follows the same visitor pattern as Drops.SQL.Compiler and
  Drops.Relation.Compilers.SchemaCompiler but works with Drops.Relation.Schema structs
  and converts them to quoted expressions for field definitions and attributes.

  The compiler replaces the SchemaFieldAST protocol approach with a more
  consistent compiler pattern that can recursively process schema components.

  ## Usage

      # Convert a Relation Schema to field AST
      schema = %Drops.Relation.Schema{...}
      field_asts = Drops.Relation.Schema.CodeCompiler.visit(schema, [])

  ## Examples

      iex> schema = %Drops.Relation.Schema{fields: [...], primary_key: ...}
      iex> asts = Drops.Relation.Schema.CodeCompiler.visit(schema, [])
      iex> is_list(asts)
      true
  """

  alias Drops.Relation.Schema

  @doc """
  Main entry point for converting Relation Schema to field AST.

  ## Parameters

  - `schema` - A Drops.Relation.Schema struct
  - `opts` - Optional compilation options

  ## Returns

  A list of quoted expressions containing field definitions and attributes.

  ## Examples

      iex> schema = %Drops.Relation.Schema{fields: [...], ...}
      iex> asts = Drops.Relation.Schema.CodeCompiler.visit(schema, [])
      iex> is_list(asts)
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

    visit(schema_tuple, new_opts)
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

  # Visit primary key tuple structure
  def visit({:primary_key, [_name, columns]}, opts) when is_list(columns) do
    case length(columns) do
      0 ->
        # No primary key
        nil

      1 ->
        # Single primary key - generate @primary_key attribute if needed
        field_name = List.first(columns)
        schema = opts[:schema]
        field = Enum.find(schema.fields, &(&1.name == field_name))
        visit({:single_primary_key_attribute, field}, opts)

      _ ->
        # Composite primary key - generate @primary_key false to disable default
        # Individual fields will be marked with primary_key: true in field definitions
        quote do
          @primary_key false
        end
    end
  end

  # Visit field tuple structure
  def visit({:field, nodes}, opts) do
    [name, type_tuple, meta_tuple] = visit(nodes, opts)

    # Extract the actual type and meta from their tuples
    type = visit(type_tuple, opts)
    meta = visit(meta_tuple, opts)

    # Skip timestamp fields
    if name in [:inserted_at, :updated_at] do
      nil
    else
      # Generate field definition based on meta information
      is_primary_key = Map.get(meta, :primary_key, false)
      pk_field_count = Map.get(meta, :primary_key_count, 0)

      cond do
        # Single primary key with special type handled by @primary_key attribute only
        is_primary_key and pk_field_count == 1 and type in [Ecto.UUID, :binary_id] ->
          nil

        # Single primary key with default type - no field definition needed, Ecto handles it
        is_primary_key and pk_field_count == 1 and type in [:id, :integer] ->
          nil

        # Composite primary key fields need field definitions with primary_key: true
        is_primary_key and pk_field_count > 1 ->
          # Build field options directly
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

          # Add primary_key: true for composite keys
          field_opts = [{:primary_key, true} | field_opts]

          # Extract type and options
          {field_type, type_opts} =
            case type do
              {type_module, opts} when is_list(opts) -> {type_module, opts}
              {type_module, opts} when is_map(opts) -> {type_module, Map.to_list(opts)}
              _ -> {type, []}
            end

          all_opts = type_opts ++ field_opts

          if all_opts == [] do
            quote do
              Ecto.Schema.field(unquote(name), unquote(field_type))
            end
          else
            quote do
              Ecto.Schema.field(unquote(name), unquote(field_type), unquote(all_opts))
            end
          end

        true ->
          # Generate regular field definition
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

          # Extract type and options
          {field_type, type_opts} =
            case type do
              {type_module, opts} when is_list(opts) -> {type_module, opts}
              {type_module, opts} when is_map(opts) -> {type_module, Map.to_list(opts)}
              _ -> {type, []}
            end

          all_opts = type_opts ++ field_opts

          if all_opts == [] do
            quote do
              Ecto.Schema.field(unquote(name), unquote(field_type))
            end
          else
            quote do
              Ecto.Schema.field(unquote(name), unquote(field_type), unquote(all_opts))
            end
          end
      end
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

  # Visit single primary key attribute generation
  def visit({:single_primary_key_attribute, field}, _opts) when is_nil(field) do
    nil
  end

  def visit({:single_primary_key_attribute, field}, _opts) do
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
end
