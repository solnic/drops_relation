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

      defstruct([:repo, schema: %{}, queryable: nil, opts: [], preloads: []])

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
    derive = Compilation.Context.get(relation, :derive)
    views = Compilation.Context.get(relation, :views)

    schema = __build_schema__(relation, schema, opts)

    Module.put_attribute(relation, :schema, schema)

    views_ast = Views.generate_functions(relation, views)
    query_api_ast = Query.generate_functions(schema)

    queryable_ast =
      if derive do
        quote do
          def queryable, do: source() |> unquote(derive.block)
        end
      else
        quote do
          def queryable, do: __schema_module__()
        end
      end

    ecto_schema_module = ecto_schema_module(relation)

    quote do
      alias Drops.Relation.{Reading, Writing}

      @schema unquote(Macro.escape(schema))

      @spec schema() :: Drops.Relation.Schema.t()
      def schema, do: @schema

      unquote(queryable_ast)
      unquote(views_ast)
      unquote_splicing(query_api_ast)

      delegate_to(get(id), to: Reading)
      delegate_to(get!(id), to: Reading)
      delegate_to(get_by(clauses), to: Reading)
      delegate_to(get_by!(clauses), to: Reading)
      delegate_to(one(), to: Reading)
      delegate_to(one!(), to: Reading)
      delegate_to(count(), to: Reading)
      delegate_to(first(), to: Reading)
      delegate_to(last(), to: Reading)

      delegate_to(insert(struct_or_changeset), to: Writing)
      delegate_to(insert!(struct_or_changeset), to: Writing)
      delegate_to(update(changeset), to: Writing)
      delegate_to(update!(changeset), to: Writing)
      delegate_to(delete(struct), to: Writing)
      delegate_to(delete!(struct), to: Writing)

      def all(relation_or_opts \\ [])

      def all([]) do
        Reading.all(relation: __MODULE__)
      end

      def all(opts) when is_list(opts) do
        Reading.all(opts |> Keyword.put(:relation, __MODULE__))
      end

      def all(%__MODULE__{} = relation) do
        Reading.all(relation)
      end

      def new(opts \\ []) do
        new(queryable(), opts)
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

      # Make the relation module itself queryable by implementing the necessary functions
      # This allows the relation module to be used directly in Ecto queries
      def __schema__(query) do
        __schema_module__().__schema__(query)
      end

      def __schema__(query, field) do
        __schema_module__().__schema__(query, field)
      end

      def __schema_module__, do: unquote(ecto_schema_module)

      def restrict(opts) when is_list(opts) do
        new(opts)
      end

      def restrict(%__MODULE__{} = relation, opts) do
        %{relation | opts: Keyword.merge(relation.opts, opts)}
      end

      def restrict(queryable, opts) do
        new(queryable, opts)
      end

      def preload(association) when is_atom(association) do
        preload(new(), [association])
      end

      def preload(%__MODULE__{} = relation, association) when is_atom(association) do
        preload(relation, [association])
      end

      def preload(%__MODULE__{} = relation, associations) when is_list(associations) do
        %{relation | preloads: relation.preloads ++ associations}
      end

      def struct(attributes \\ %{}) do
        struct(__schema_module__(), attributes)
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
    schema = Compilation.Context.get(relation, :schema)
    views = Compilation.Context.get(relation, :views)

    ecto_schema = Generator.generate_module_content(relation.schema(), schema.block || [])

    Module.create(relation.__schema_module__(), ecto_schema, Macro.Env.location(__ENV__))

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

  defp infer_source_schema(relation, name, opts) do
    repo = opts[:repo]
    file = Drops.Relation.Cache.get_cache_file_path(repo, name)

    Module.put_attribute(relation, :external_resource, file)

    Drops.Relation.Cache.get_cached_schema(repo, name)
  end

  defp ecto_schema_module(relation) do
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
