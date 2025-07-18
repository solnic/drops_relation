defmodule Drops.Relation do
  @moduledoc """
  Provides a convenient query API that wraps Ecto.Schema and delegates to Ecto.Repo functions.

  This module generates relation modules that automatically infer database schemas and provide
  a query API that delegates to the configured Ecto repository. All functions accept an optional
  `:repo` option that overrides the default repository configured via the `use` macro.

  ## Usage

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo, name: "users"
      end

      # Query functions automatically use the configured repo
      user = MyApp.Users.get(1)
      users = MyApp.Users.all()

  ## Query API

  All query functions delegate to the corresponding `Ecto.Repo` functions. See the
  [Ecto.Repo documentation](https://hexdocs.pm/ecto/Ecto.Repo.html) for detailed information
  about each function's behavior and options.

  The `:repo` option is automatically passed based on the repository configured in the `use` macro,
  but can be overridden by passing a `:repo` option to any function call.
  """

  alias Drops.Relation.{
    Compilation,
    Generator,
    Schema,
    Query,
    Views
  }

  defmacro __using__(opts) do
    __define_relation__(Macro.expand(opts, __CALLER__))
  end

  def __define_relation__(opts) do
    config =
      if opts[:source] do
        quote location: :keep do
          @config unquote(opts[:source].__config__())
          def __config__, do: @config

          @source unquote(opts[:source])
          def source, do: @source
        end
      else
        quote do
          @config Application.compile_env(
                    unquote(opts)[:repo].config()[:otp_app],
                    [:drops, :relation],
                    []
                  )
          def __config__, do: @config
        end
      end

    quote location: :keep do
      import Drops.Relation

      unquote(config)

      @context Compilation.Context.new(__MODULE__, @config)

      @before_compile Drops.Relation
      @after_compile Drops.Relation

      @opts unquote(opts)
      def opts, do: @opts
      def opts(name), do: Keyword.get(opts(), name)

      defstruct([:repo, :schema, :queryable, opts: [], preloads: []])

      defmacro __using__(opts) do
        Drops.Relation.__define_relation__(
          Keyword.put(Macro.expand(opts, __CALLER__), :source, __MODULE__)
        )
      end
    end
  end

  defmacro schema(fields, opts \\ [])

  defmacro schema(name, opts) when is_binary(name) do
    block = opts[:do]

    quote do
      @context Compilation.Context.update(__MODULE__, :schema, [
                 unquote(name),
                 unquote(Keyword.delete(opts, :do)),
                 unquote(Macro.escape(block))
               ])
    end
  end

  defmacro schema(fields, opts) when is_list(fields) do
    quote do
      @context Compilation.Context.update(__MODULE__, :schema, [unquote(fields), unquote(opts)])
    end
  end

  defmacro view(name, do: block) do
    quote do
      @context Compilation.Context.update(__MODULE__, :view, [
                 unquote(name),
                 unquote(Macro.escape(block))
               ])
    end
  end

  defmacro derive(do: block) do
    quote do
      @context Compilation.Context.update(__MODULE__, :derive, [unquote(Macro.escape(block))])
    end
  end

  defmacro delegate_to(fun, to: target) do
    fun = Macro.escape(fun)

    quote bind_quoted: [fun: fun, target: target] do
      {name, args} = Macro.decompose_call(fun)

      final_args =
        case args do
          [] -> [[relation: __MODULE__]]
          _ -> args ++ [[relation: __MODULE__]]
        end

      def unquote({name, [line: __ENV__.line], args}) do
        unquote(target).unquote(name)(unquote_splicing(final_args))
      end
    end
  end

  defmacro __before_compile__(env) do
    relation = env.module

    opts = Module.get_attribute(relation, :opts)
    schema = Compilation.Context.get(relation, :schema)
    views = Compilation.Context.get(relation, :views)

    schema = __build_schema__(relation, schema, opts)

    Module.put_attribute(relation, :schema, schema)

    views_ast = Views.generate_functions(relation, views)
    query_api_ast = Query.generate_functions(schema)

    quote do
      use Drops.Relation.Reading
      use Drops.Relation.Writing
      use Drops.Relation.Queryable

      @schema unquote(Macro.escape(schema))

      @spec schema() :: Drops.Relation.Schema.t()
      def schema, do: @schema

      unquote(views_ast)
      unquote_splicing(query_api_ast)

      def new(opts \\ []) do
        new(__schema_module__(), opts)
      end

      def new(queryable, opts) do
        Kernel.struct(__MODULE__, %{
          queryable: queryable,
          schema: Keyword.get(opts, :schema, schema()),
          repo: unquote(opts[:repo]),
          opts: opts,
          preloads: []
        })
      end
    end
  end

  defmacro __after_compile__(env, _) do
    relation = env.module
    schema = Module.get_attribute(relation, :schema)

    if schema do
      __finalize_relation__(relation)
    else
      []
    end
  end

  def __build_schema__(relation, spec, opts) do
    case spec do
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
  end

  def __finalize_relation__(relation) do
    views = Compilation.Context.get(relation, :views)
    Enum.each(views, fn view -> Views.create_module(relation, view.name, view.block) end)

    quote location: :keep do
      defimpl Enumerable, for: unquote(relation) do
        import Ecto.Query

        def count(relation) do
          {:ok, length(materialize(relation))}
        end

        def member?(relation, value) do
          case materialize(relation) do
            {:ok, list} -> {:ok, value in list}
            {:error, _} = error -> error
          end
        end

        def slice(relation) do
          list = materialize(relation)
          size = length(list)

          {:ok, size, fn start, count, _step -> Enum.slice(list, start, count) end}
        end

        def reduce(relation, acc, fun) do
          Enumerable.List.reduce(materialize(relation), acc, fun)
        end

        defp materialize(relation) do
          unquote(relation).all(relation)
        end
      end
    end
  end

  defp infer_source_schema(relation, name, opts) do
    repo = opts[:repo]
    file = Drops.Relation.Cache.get_cache_file_path(repo, name)

    Module.put_attribute(relation, :external_resource, file)

    Drops.Relation.Cache.get_cached_schema(repo, name)
  end
end
