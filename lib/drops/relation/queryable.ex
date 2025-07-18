defmodule Drops.Relation.Queryable do
  alias Drops.Relation.Compilation
  alias Drops.Relation.Generator

  alias __MODULE__

  defmacro __using__(_opts) do
    relation = __CALLER__.module

    derive = Compilation.Context.get(relation, :derive)
    ecto_schema_module = Queryable.ecto_schema_module(relation)

    ecto_funcs =
      quote do
        defdelegate __schema__(key), to: unquote(ecto_schema_module)
        defdelegate __schema__(key, value), to: unquote(ecto_schema_module)

        def __schema_module__, do: unquote(ecto_schema_module)
      end

    queryable_fun =
      if derive do
        quote do
          def queryable, do: unquote(derive.block)
        end
      else
        quote do
          def queryable, do: __schema_module__()
        end
      end

    quote do
      @after_compile unquote(__MODULE__)

      unquote(queryable_fun)
      unquote(ecto_funcs)
    end
  end

  defmacro __after_compile__(env, _) do
    relation = env.module
    schema = Compilation.Context.get(relation, :schema)

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
    namespace = Compilation.Context.config(relation, :ecto_schema_namespace)

    module =
      case Compilation.Context.get(relation, :schema).opts[:struct] do
        nil ->
          Compilation.Context.config(relation, :ecto_schema_module)

        value ->
          value
      end

    Module.concat(namespace ++ [module])
  end
end
