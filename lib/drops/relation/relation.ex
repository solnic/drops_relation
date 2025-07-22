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

  alias Drops.Relation.Compilation

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

          @view unquote(opts[:view])
          def name, do: @view
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

    plugins =
      Enum.map(plugins(opts), fn plugin ->
        quote do
          use unquote(plugin)
        end
      end)

    quote location: :keep do
      import Drops.Relation

      unquote(config)

      @context Compilation.Context.new(__MODULE__, @config)

      Module.register_attribute(__MODULE__, :plugins, accumulate: true)

      unquote_splicing(plugins)

      @opts unquote(opts)
      def opts, do: @opts
      def opts(name), do: Keyword.get(opts(), name)

      defmacro __using__(opts) do
        Drops.Relation.__define_relation__(
          Keyword.put(Macro.expand(opts, __CALLER__), :source, __MODULE__)
        )
      end
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

  defp plugins(opts) do
    case opts[:plugins] do
      nil ->
        Drops.Relation.Config.default_plugins(opts[:repo])

      plugins when is_list(plugins) ->
        plugins
    end
  end
end
