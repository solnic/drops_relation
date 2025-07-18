defmodule Drops.Relation.Plugins.Schema do
  alias Drops.Relation.Compilation
  alias Drops.Relation.Schema
  alias Drops.Relation.Cache
  alias Drops.Relation.Generator

  defmacro __using__(_opts) do
    relation = __CALLER__.module
    opts = Module.get_attribute(relation, :opts)

    __MODULE__.put_schema(relation, opts)

    quote location: :keep do
      @spec schema() :: Schema.t()
      def schema, do: @schema
    end
  end

  def put_schema(relation, opts) do
    schema =
      case Compilation.Context.get(relation, :schema) do
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
