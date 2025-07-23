defmodule Drops.Relation.Plugins.Queryable do
  @moduledoc false

  alias Drops.Relation.Generator
  alias Drops.Relation.Plugins.Queryable.Operations

  use Drops.Relation.Plugin do
    defstruct([:repo, :schema, :queryable, :associations, operations: [], opts: [], meta: %{}])
  end

  def on(:before_compile, relation, %{opts: opts}) do
    ecto_schema_module = ecto_schema_module(relation)

    ecto_funcs =
      quote do
        defdelegate __schema__(key), to: unquote(ecto_schema_module)
        defdelegate __schema__(key, value), to: unquote(ecto_schema_module)

        def __schema_module__, do: unquote(ecto_schema_module)

        def __associations__ do
          Enum.reduce(__schema__(:associations), %{}, fn name, acc ->
            Map.put(acc, name, __schema__(:association, name))
          end)
        end
      end

    quote do
      unquote(ecto_funcs)

      @type t :: __MODULE__

      @spec repo() :: module()
      def repo, do: unquote(opts[:repo])

      def new(opts \\ [])

      @spec new(keyword()) :: t()
      def new(opts) when is_list(opts), do: new(queryable(), opts)

      @spec new(Ecto.Queryable.t()) :: t()
      def new(queryable) when is_atom(queryable) or is_struct(queryable), do: new(queryable, [])

      @spec new(Ecto.Queryable.t(), keyword()) :: t()
      def new(queryable, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          schema: schema(),
          associations: __associations__(),
          repo: repo(),
          operations: [],
          opts: opts,
          meta: %{}
        })
      end

      @spec queryable() :: Ecto.Queryable.t()
      def queryable(), do: __schema_module__()
      defoverridable queryable: 0

      def add_operation(%__MODULE__{operations: operations} = relation, name, opts \\ []) do
        relation_opts = relation.opts

        if name in operations do
          current_opts = Keyword.get(relation_opts, name, [])
          updated_opts = Keyword.put(relation_opts, name, current_opts ++ List.wrap(opts))

          %{relation | opts: updated_opts}
        else
          updated_opts = Keyword.put(relation_opts, name, List.wrap(opts))

          %{relation | operations: operations ++ [name], opts: updated_opts}
        end
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
        @compilers [
          restrict: Operations.Restrict.Compiler,
          order: Operations.Order.Compiler,
          preload: Operations.Preload.Compiler
        ]

        def to_query(%{operations: [], queryable: queryable}) do
          Ecto.Queryable.to_query(queryable)
        end

        def to_query(%{operations: operations, queryable: queryable, opts: opts} = relation) do
          Enum.reduce(operations, Ecto.Queryable.to_query(queryable), fn name, query ->
            case @compilers[name] do
              nil ->
                query

              compiler ->
                case compiler.visit(relation, %{query: query, opts: opts}) do
                  {:ok, result_query} ->
                    result_query

                  {:error, errors} ->
                    raise Drops.Relation.Plugins.Queryable.InvalidQueryError, errors: errors
                end
            end
          end)
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
