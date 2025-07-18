defmodule Drops.Relation.Plugins.Schema do
  alias Drops.Relation.Schema
  alias Drops.Relation.Cache
  alias Drops.Relation.Generator

  use Drops.Relation.Plugin, imports: [schema: 1, schema: 2]

  defmacro schema(fields, opts \\ [])

  defmacro schema(name, opts) when is_binary(name) do
    block = opts[:do]

    quote do
      @context update_context(__MODULE__, :schema, [
                 unquote(name),
                 unquote(Keyword.delete(opts, :do)),
                 unquote(Macro.escape(block))
               ])
    end
  end

  defmacro schema(fields, opts) when is_list(fields) do
    quote do
      @context update_context(__MODULE__, :schema, [unquote(fields), unquote(opts)])
    end
  end

  def on(:before_compile, relation, %{opts: opts}) do
    put_schema(relation, opts)

    quote location: :keep do
      @spec schema() :: Schema.t()
      def schema, do: @schema
    end
  end

  def put_schema(relation, opts) do
    schema =
      case context(relation, :schema) do
        %{name: nil, fields: fields} when is_list(fields) ->
          Schema.project(opts[:source].schema(), fields)

        %{name: name, infer: true, block: block} ->
          source_schema = infer_source_schema(relation, name, opts)

          if block do
            Schema.merge(source_schema, Generator.schema_from_block(name, block))
          else
            source_schema
          end
      end

    Module.put_attribute(relation, :schema, schema)
  end

  defp infer_source_schema(relation, name, opts) do
    repo = opts[:repo]
    file = Cache.get_cache_file_path(repo, name)

    Module.put_attribute(relation, :external_resource, file)

    Cache.get_cached_schema(repo, name)
  end
end
