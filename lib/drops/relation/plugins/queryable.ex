defmodule Drops.Relation.Plugins.Queryable do
  alias Drops.Relation.Generator

  use Drops.Relation.Plugin do
    defstruct([:repo, :schema, :queryable, opts: [], preloads: []])
  end

  def on(:before_compile, relation, %{opts: opts}) do
    ecto_schema_module = ecto_schema_module(relation)

    ecto_funcs =
      quote do
        defdelegate __schema__(key), to: unquote(ecto_schema_module)
        defdelegate __schema__(key, value), to: unquote(ecto_schema_module)

        def __schema_module__, do: unquote(ecto_schema_module)
      end

    quote do
      unquote(ecto_funcs)

      @spec repo() :: module()
      def repo, do: unquote(opts[:repo])

      def new(), do: new([])

      def new(opts) do
        new(__schema_module__(), opts)
      end

      def new(queryable, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          schema: schema(),
          repo: repo(),
          opts: opts,
          preloads: []
        })
      end
    end
  end

  def on(:after_compile, relation, _) do
    schema = context(relation, :schema)
    ecto_schema = Generator.generate_module_content(relation.schema(), schema.block || [])

    Module.create(
      relation.__schema_module__(),
      ecto_schema,
      Macro.Env.location(__ENV__)
    )

    quote location: :keep do
      defimpl Ecto.Queryable, for: unquote(relation) do
        import Ecto.Query

        def to_query(relation) do
          base_query = Ecto.Queryable.to_query(relation.queryable)

          query_with_restrictions =
            build_query_with_restrictions(base_query, relation.opts)

          apply_preloads(query_with_restrictions, relation.preloads)
        end

        defp build_query_with_restrictions(queryable, []) do
          queryable
        end

        defp build_query_with_restrictions(queryable, opts) do
          Enum.reduce(opts, queryable, fn {field, value}, query ->
            where(query, [r], field(r, ^field) == ^value)
          end)
        end

        defp apply_preloads(queryable, []) do
          queryable
        end

        defp apply_preloads(queryable, preloads) do
          from(q in queryable, preload: ^preloads)
        end
      end
    end
  end

  def ecto_schema_module(relation) do
    namespace = config(relation, :ecto_schema_namespace)

    module =
      case context(relation, :schema).opts[:struct] do
        nil ->
          config(relation, :ecto_schema_module)

        value ->
          value
      end

    Module.concat(namespace ++ [module])
  end
end
