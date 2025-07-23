defmodule Drops.Relation.Schema.Patcher do
  @moduledoc false

  alias Sourceror.Zipper

  @doc """
  Main entry point for patching a schema module.

  ## Parameters

  - `zipper` - Sourceror.Zipper positioned at the module root
  - `compiled_parts` - Grouped compilation result from CodeCompiler with `:grouped` option
  - `table_name` - The database table name for the schema

  ## Returns

  - `{:ok, updated_zipper}` - Successfully patched zipper
  - `{:error, reason}` - Patching failed

  ## Examples

      iex> zipper = Sourceror.Zipper.zip(existing_ast)
      iex> compiled_parts = %{attributes: %{primary_key: [...], ...}, fields: [...]}
      iex> {:ok, updated_zipper} = Patcher.patch_schema_module(zipper, compiled_parts, "users")
  """
  @spec patch_schema_module(Zipper.t(), map(), String.t()) :: {:ok, Zipper.t()}
  def patch_schema_module(zipper, compiled_parts, table_name) do
    # Use sophisticated Sourceror-based patching to preserve custom code
    updated_zipper =
      zipper
      |> update_primary_key_attributes(compiled_parts.primary_key)
      |> update_foreign_key_type_attributes(compiled_parts.foreign_key_type)
      |> update_schema_block(compiled_parts.fields, table_name)

    {:ok, updated_zipper}
  end

  @doc """
  Updates the schema block content with new field definitions.

  ## Parameters

  - `zipper` - Sourceror.Zipper positioned at the module
  - `fields` - List of field definition AST nodes
  - `table_name` - The database table name

  ## Returns

  Updated zipper with schema block modified.
  """
  @spec update_schema_block(Zipper.t(), list(), String.t()) :: Zipper.t()
  def update_schema_block(zipper, fields, table_name) do
    case find_schema_block(zipper, table_name) do
      {:ok, schema_zipper} ->
        replace_schema_fields(schema_zipper, fields)

      :error ->
        # Schema block not found, create a new one
        create_schema_block(zipper, fields, table_name)
    end
  end

  # Private helper functions

  # Updates @primary_key attributes
  defp update_primary_key_attributes(zipper, []), do: zipper

  defp update_primary_key_attributes(zipper, primary_key_attr) do
    zipper
    |> remove_attribute_definitions(:primary_key)
    |> add_attributes_after_imports(primary_key_attr)
  end

  # Updates @foreign_key_type attributes
  defp update_foreign_key_type_attributes(zipper, foreign_key_attrs) do
    if Enum.empty?(foreign_key_attrs) do
      zipper
    else
      # Remove existing @foreign_key_type attributes and add new ones
      zipper
      |> remove_attribute_definitions(:foreign_key_type)
      |> add_attributes_after_imports(foreign_key_attrs)
    end
  end

  # Removes all attribute definitions of a specific type
  defp remove_attribute_definitions(zipper, attribute_name) do
    # Use a simple traverse to transform the AST, removing matching attributes
    Zipper.traverse(zipper, fn node_zipper ->
      # node_zipper is a zipper, so we call Zipper.node to get the AST
      case Zipper.node(node_zipper) do
        {:@, _, [{^attribute_name, _, _}]} ->
          # Remove this node
          Zipper.remove(node_zipper)

        _ ->
          # Keep this node
          node_zipper
      end
    end)
  end

  # Adds attributes after import statements
  defp add_attributes_after_imports(zipper, []), do: zipper

  defp add_attributes_after_imports(zipper, attribute) when is_tuple(attribute) do
    # Find the best insertion point for attributes
    case find_attribute_insertion_point(zipper) do
      {:ok, insertion_zipper} ->
        # Insert attributes after the found insertion point
        final_zipper = Zipper.insert_right(insertion_zipper, attribute)

        Zipper.top(final_zipper)

      :error ->
        add_attributes_at_module_start(zipper, attribute)
    end
  end

  # Finds the best insertion point for attributes (after use/import statements)
  defp find_attribute_insertion_point(zipper) do
    # Look for the last use/import statement in the module using traverse
    {_, last_found} =
      Zipper.traverse(zipper, nil, fn node_zipper, acc ->
        # node_zipper is a zipper, so we call Zipper.node to get the AST
        case Zipper.node(node_zipper) do
          {:use, _, _} -> {node_zipper, node_zipper}
          {:import, _, _} -> {node_zipper, node_zipper}
          {:require, _, _} -> {node_zipper, node_zipper}
          _ -> {node_zipper, acc}
        end
      end)

    case last_found do
      nil -> :error
      found_zipper -> {:ok, found_zipper}
    end
  end

  # Adds attributes at the start of module body (after defmodule line)
  defp add_attributes_at_module_start(zipper, attributes) do
    case Zipper.down(zipper) do
      nil ->
        zipper

      body_zipper ->
        Enum.reduce(attributes, body_zipper, fn attr, acc_zipper ->
          Zipper.insert_right(acc_zipper, attr)
        end)
        |> Zipper.up()
    end
  end

  # Finds the schema block in the module
  defp find_schema_block(zipper, table_name) do
    # Use find to search for schema blocks - the predicate receives the raw AST node
    found_zipper =
      Zipper.find(zipper, fn ast_node ->
        # ast_node is the raw AST node, not a zipper
        case ast_node do
          {:schema, _, [table_arg | _]} ->
            # Check if the table argument matches our table name
            # Handle both string and atom table names, and AST nodes
            table_matches?(table_arg, table_name)

          _ ->
            false
        end
      end)

    case found_zipper do
      nil -> :error
      schema_zipper -> {:ok, schema_zipper}
    end
  end

  # Helper function to check if table names match, handling string/atom conversion
  defp table_matches?(table_arg, table_name) do
    # Extract the actual value from AST nodes
    actual_table_arg = extract_table_name_from_ast(table_arg)

    cond do
      # Exact match
      actual_table_arg == table_name ->
        true

      # String table_arg, atom table_name
      is_binary(actual_table_arg) and is_atom(table_name) ->
        actual_table_arg == Atom.to_string(table_name)

      # Atom table_arg, string table_name
      is_atom(actual_table_arg) and is_binary(table_name) ->
        Atom.to_string(actual_table_arg) == table_name

      # Both strings
      is_binary(actual_table_arg) and is_binary(table_name) ->
        actual_table_arg == table_name

      # Both atoms
      is_atom(actual_table_arg) and is_atom(table_name) ->
        actual_table_arg == table_name

      # No match
      true ->
        false
    end
  end

  # Helper function to extract table name from AST nodes
  defp extract_table_name_from_ast(ast_node) do
    case ast_node do
      # Handle string literals with metadata: {:__block__, [...], ["users"]}
      {:__block__, _meta, [table_name]} when is_binary(table_name) ->
        table_name

      # Handle atom literals with metadata: {:__block__, [...], [:users]}
      {:__block__, _meta, [table_name]} when is_atom(table_name) ->
        table_name

      # Handle simple string
      table_name when is_binary(table_name) ->
        table_name

      # Handle simple atom
      table_name when is_atom(table_name) ->
        table_name

      # Fallback for other cases
      _ ->
        ast_node
    end
  end

  # Replaces field definitions in the schema block
  defp replace_schema_fields(schema_zipper, fields) do
    # Use Sourceror's within function to work on the schema subtree
    Zipper.within(schema_zipper, fn schema_subtree ->
      # Remove existing field definitions but preserve timestamps() and associations
      cleaned_subtree = remove_field_definitions(schema_subtree)

      # Find the best insertion point for new fields
      insertion_point = find_field_insertion_point(cleaned_subtree)

      # Add new field definitions at the insertion point
      Enum.reduce(fields, insertion_point, fn field_def, acc_zipper ->
        Zipper.insert_left(acc_zipper, field_def)
      end)
      |> Zipper.top()
    end)
  end

  # Removes field() calls but preserves other content like timestamps(), associations
  defp remove_field_definitions(zipper) do
    Zipper.traverse(zipper, fn node_zipper ->
      # node_zipper is a zipper, so we call Zipper.node to get the AST
      case Zipper.node(node_zipper) do
        {:field, _, _} ->
          # Remove field definition
          Zipper.remove(node_zipper)

        # Also remove belongs_to, has_one, has_many if we want to regenerate them
        # For now, preserve them to maintain custom associations
        _ ->
          node_zipper
      end
    end)
  end

  # Finds the best insertion point for field definitions (before timestamps if it exists)
  defp find_field_insertion_point(zipper) do
    # Look for timestamps() call manually - predicate receives raw AST node
    case Zipper.find(zipper, fn ast_node ->
           case ast_node do
             {:timestamps, _, _} -> true
             _ -> false
           end
         end) do
      nil ->
        # No timestamps found, find the end of the schema block
        find_schema_block_end(zipper)

      timestamps_zipper ->
        # Insert before timestamps
        timestamps_zipper
    end
  end

  # Finds the end of the schema block for field insertion
  defp find_schema_block_end(zipper) do
    # Navigate to the rightmost position in the current level
    Zipper.rightmost(zipper)
  end

  # Creates a new schema block if one doesn't exist
  defp create_schema_block(zipper, fields, table_name) do
    # Create the schema block AST
    schema_ast =
      quote do
        schema unquote(table_name) do
          unquote_splicing(fields)
          timestamps()
        end
      end

    # Find a good insertion point (after attributes, before functions)
    case find_schema_insertion_point(zipper) do
      {:ok, insertion_zipper} ->
        Zipper.insert_right(insertion_zipper, schema_ast)
        |> Zipper.top()

      :error ->
        # Add at the end of module body
        add_at_module_end(zipper, schema_ast)
    end
  end

  # Finds a good insertion point for the schema block
  defp find_schema_insertion_point(zipper) do
    # Look for the last attribute definition, import, or use statement using traverse
    {_, last_found} =
      Zipper.traverse(zipper, nil, fn node_zipper, acc ->
        # node_zipper is a zipper, so we call Zipper.node to get the AST
        case Zipper.node(node_zipper) do
          {:@, _, _} -> {node_zipper, node_zipper}
          {:import, _, _} -> {node_zipper, node_zipper}
          {:use, _, _} -> {node_zipper, node_zipper}
          {:require, _, _} -> {node_zipper, node_zipper}
          _ -> {node_zipper, acc}
        end
      end)

    case last_found do
      nil -> :error
      found_zipper -> {:ok, found_zipper}
    end
  end

  # Adds content at the end of module body
  defp add_at_module_end(zipper, content) do
    # Navigate to the module body and add content at the end
    case Zipper.down(zipper) do
      nil ->
        zipper

      body_zipper ->
        # Find the rightmost position in the module body
        rightmost = Zipper.rightmost(body_zipper)

        Zipper.insert_right(rightmost, content)
        |> Zipper.up()
    end
  end
end
