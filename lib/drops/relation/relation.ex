defmodule Drops.Relation do
  @moduledoc """
  High-level API for defining database relations with automatic schema inference.

  Drops.Relation automatically introspects database tables and generates Ecto schemas,
  providing a convenient query API that delegates to Ecto.Repo functions. Relations
  support composable queries, custom query definitions, and views.

  ## Configuration

  Relations can be configured at the application level:

      config :my_app, :drops,
        relation: [
          repo: MyApp.Repo
        ]

  ## Reading and Writing

      iex> defmodule MyApp.Users do
      ...>   use Drops.Relation, otp_app: :my_app
      ...>
      ...>   schema("users", infer: true)
      ...> end
      ...>
      iex> {:ok, user} = MyApp.Users.insert(%{name: "Jane", email: "jane@doe.org", age: 42})
      iex> user.name
      "Jane"
      iex> user.email
      "jane@doe.org"
      ...>
      iex> [user] = MyApp.Users.all()
      iex> user.name
      "Jane"
      ...>
      iex> MyApp.Users.count()
      1

  ## Composable Queries

      iex> defmodule MyApp.Users do
      ...>   use Drops.Relation, otp_app: :my_app
      ...>
      ...>   schema("users", infer: true)
      ...> end
      ...>
      iex> MyApp.Users.insert(%{name: "John", email: "john@doe.org", active: true})
      iex> MyApp.Users.insert(%{name: "Jane", email: "jane@doe.org", active: true})
      iex> MyApp.Users.insert(%{name: "Joe", email: "joe@doe.org", active: false})
      ...>
      iex> query = MyApp.Users
      ...>          |> MyApp.Users.restrict(active: true)
      ...>          |> MyApp.Users.order(:name)
      ...>
      iex> [jane, john] = Enum.to_list(query)
      iex> jane.name
      "Jane"
      iex> john.name
      "John"
  """

  alias Drops.Relation.Compilation
  alias __MODULE__

  defmacro __using__(opts) do
    __define_relation__(Compilation.expand_opts(opts, __CALLER__))
  end

  @doc false
  def __define_relation__(opts) do
    config =
      if opts[:source] do
        quote location: :keep do
          @config unquote(opts[:source].__config__())
          def __config__, do: @config

          @source unquote(opts[:source])
          def source, do: @source

          @view unquote(opts[:view])
          def name, do: @view
        end
      else
        repo = if opts[:repo], do: opts[:repo], else: nil
        otp_app = if repo, do: repo.config()[:otp_app], else: opts[:otp_app]

        quote do
          @config Application.compile_env(unquote(otp_app), [:drops, :relation], [])
          def __config__, do: @config
        end
      end

    plugins =
      Enum.map(plugins(opts), fn plugin ->
        quote do
          use unquote(plugin)
        end
      end)

    quote location: :keep do
      import Relation

      unquote(config)

      @context Compilation.Context.new(__MODULE__, @config)

      Module.register_attribute(__MODULE__, :plugins, accumulate: true)

      unquote_splicing(plugins)

      @doc """
      Returns relation opts passed to the using macro
      """
      @opts Keyword.put(unquote(opts), :repo, @config[:repo] || unquote(opts[:repo]))
      @spec opts() :: map()
      def opts, do: @opts

      @doc """
      Returns value for a given option from the opts
      """
      @spec opts(atom()) :: term()
      def opts(name), do: Keyword.get(opts(), name)

      defmacro __using__(opts) do
        Relation.__define_relation__(
          Compilation.expand_opts(opts, __CALLER__, source: __MODULE__)
        )
      end
    end
  end

  @doc """
  Macro for creating delegation functions that automatically inject relation context.

  This macro generates functions that delegate to plugin modules while automatically
  injecting the current relation module as context. It's used by plugins to create
  clean APIs that don't require users to manually pass relation information.

  ## Parameters

  - `fun` - The function call pattern to delegate (e.g., `get(id)`, `all()`)
  - `target` - The target module to delegate to (specified with `to:` keyword)

  ## Behaviour

  The macro automatically:
  1. Extracts the function name and arguments from the call pattern
  2. Adds `[relation: __MODULE__]` as the final argument to the delegation
  3. Generates a function definition that calls the target module

  ## Examples

      iex> defmodule TestPlugin do
      ...>   use Drops.Relation.Plugin
      ...>
      ...>   def on(:before_compile, _relation, _attributes) do
      ...>     quote do
      ...>       delegate_to(test_function(arg), to: unquote(__MODULE__))
      ...>     end
      ...>   end
      ...>
      ...>   def test_function(arg, opts) do
      ...>     {arg, opts[:relation]}
      ...>   end
      ...> end
      ...>
      iex> defmodule MyApp.Users do
      ...>   use Drops.Relation, otp_app: :my_app, plugins: [TestPlugin]
      ...>
      ...>   schema("users", infer: true)
      ...> end
      ...>
      iex> MyApp.Users.test_function("hello")
      {"hello", Drops.RelationTest.MyApp.Users}
  """
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

  @core_plugins [
    Drops.Relation.Plugins.Schema,
    Drops.Relation.Plugins.Queryable,
    Drops.Relation.Plugins.Loadable
  ]

  defp plugins(opts) do
    plugins_from_opts =
      case opts[:plugins] do
        nil ->
          Drops.Relation.Config.default_plugins(opts[:repo])

        plugins when is_list(plugins) ->
          plugins
      end

    Enum.uniq(@core_plugins ++ plugins_from_opts)
  end
end
