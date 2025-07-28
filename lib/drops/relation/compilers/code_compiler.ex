defmodule Drops.Relation.Compilers.CodeCompiler do
  @moduledoc false

  alias Drops.Relation.Schema
  alias Drops.Relation.Schema.Field

  def visit(node, opts \\ %{})

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
    fields: [...],  # field() calls
    schema_options: [...]      # Any schema-level options
  }
  ```

  When `:grouped` is false (default), returns a flat list of quoted expressions for backward compatibility.

  ## Examples

      iex> schema = %Drops.Relation.Schema{fields: [...], ...}
      iex> asts = Drops.Relation.Compilers.CodeCompiler.visit(schema, %{})
      iex> is_list(asts)
      true

      iex> grouped = Drops.Relation.Compilers.CodeCompiler.visit(schema, %{grouped: true})
      iex> is_map(grouped) and Map.has_key?(grouped, :attributes)
      true
  """
  def visit(%Schema{} = schema, opts) do
    opts = Map.put(opts, :schema, schema)

    result =
      Enum.reduce(schema, %{}, fn {key, value}, acc ->
        case visit({key, value}, opts) do
          nil ->
            acc

          [] ->
            acc

          result ->
            Map.put(acc, key, result)
        end
      end)

    %{
      primary_key: Map.get(result, :primary_key, []),
      foreign_key_type: Map.get(result, :foreign_keys, []),
      fields: Map.get(result, :fields, [])
    }
  end

  def visit({:source, _source}, _opts) do
    nil
  end

  def visit({:primary_key, nil}, _opts) do
    nil
  end

  def visit({:primary_key, primary_key}, _opts) do
    case primary_key.meta.composite do
      false ->
        field = List.first(primary_key.fields)
        generate_single_primary_key_attribute(field)

      true ->
        quote do
          @primary_key false
        end
    end
  end

  def visit({:foreign_keys, _foreign_keys}, %{schema: schema}) do
    Enum.find_value(schema.fields, fn field ->
      is_foreign_key = Map.get(field.meta, :foreign_key, false)

      if is_foreign_key and field.type in [:binary_id, Ecto.UUID] do
        quote do
          @foreign_key_type :binary_id
        end
      else
        []
      end
    end)
  end

  def visit({:fields, fields}, opts) do
    Enum.map(fields, &visit(&1, opts))
  end

  def visit({type, _}, _opts) when type in [:index, :foreign_key], do: nil
  def visit(nil, _opts), do: nil

  def visit(%Field{} = field, %{schema: schema} = opts) do
    [name, type, meta] = Enum.map(field, &visit(&1, opts))

    cond do
      name in [:inserted_at, :updated_at] ->
        nil

      meta[:association] ->
        nil

      meta[:embed] ->
        generate_embed_definition(name, meta)

      Schema.primary_key?(schema, field) ->
        nil

      true ->
        generate_field_definition(name, type, meta)
    end
  end

  def visit({:type, type}, _opts) when is_atom(type) do
    type
  end

  def visit({:type, {type_module, type_opts}}, _opts) do
    {type_module, type_opts}
  end

  def visit({:meta, meta}, _opts) when is_map(meta) do
    meta
  end

  def visit({type, type_opts}, _opts) when is_atom(type) and is_list(type_opts) do
    {type, type_opts}
  end

  def visit({type, type_opts}, _opts) when is_atom(type) and is_map(type_opts) do
    {type, Map.to_list(type_opts)}
  end

  def visit(value, _opts) when is_atom(value), do: value
  def visit(value, _opts) when is_binary(value), do: value
  def visit(value, _opts) when is_number(value), do: value

  def visit(enumerable, opts) when is_map(enumerable) do
    Enum.reduce(enumerable, %{}, fn {key, value}, acc ->
      visited_key = visit(key, opts)
      visited_value = visit(value, opts)
      Map.put(acc, visited_key, visited_value)
    end)
  end

  def visit(enumerable, opts) when is_list(enumerable) and not is_binary(enumerable) do
    Enum.map(enumerable, &visit(&1, opts))
  end

  def visit(value, _opts), do: value

  defp generate_single_primary_key_attribute(nil), do: nil

  defp generate_single_primary_key_attribute(field) do
    cond do
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
        []
    end
  end

  defp generate_field_definition(name, type, meta) do
    field_opts = if meta[:primary_key], do: [{:primary_key, true}], else: []

    source = Map.get(meta, :source, name)
    field_opts = if source != name, do: [{:source, source} | field_opts], else: field_opts

    field_opts =
      case Map.get(meta, :default) do
        nil -> field_opts
        :auto_increment -> field_opts
        value -> [{:default, value} | field_opts]
      end

    field_opts =
      if Map.get(meta, :function_default, false) do
        [{:read_after_writes, true} | field_opts]
      else
        field_opts
      end

    {field_type, type_opts} =
      case type do
        {:parameterized, {type_module, type_config}} when is_map(type_config) ->
          case type_module do
            Ecto.Enum ->
              values = Map.get(type_config, :mappings, []) |> Keyword.keys()
              {type_module, [values: values]}

            _ ->
              {type_module, []}
          end

        {type_module, opts} when is_list(opts) ->
          {type_module, opts}

        {type_module, opts} when is_map(opts) ->
          {type_module, Map.to_list(opts)}

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
        field(unquote(name), unquote(field_type), unquote(Macro.escape(all_opts)))
      end
    end
  end

  @spec generate_embed_definition(atom(), map()) :: Macro.t()
  defp generate_embed_definition(name, meta) do
    cardinality = meta[:embed_cardinality]
    related = meta[:embed_related]
    on_replace = meta[:embed_on_replace]

    embed_opts = []

    embed_opts =
      if on_replace != :raise, do: [{:on_replace, on_replace} | embed_opts], else: embed_opts

    case cardinality do
      :one ->
        if embed_opts == [] do
          quote do
            embeds_one(unquote(name), unquote(related))
          end
        else
          quote do
            embeds_one(unquote(name), unquote(related), unquote(embed_opts))
          end
        end

      :many ->
        if embed_opts == [] do
          quote do
            embeds_many(unquote(name), unquote(related))
          end
        else
          quote do
            embeds_many(unquote(name), unquote(related), unquote(embed_opts))
          end
        end
    end
  end
end
