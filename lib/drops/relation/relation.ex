defmodule Drops.Relation do
  @moduledoc """
  High-level API for defining database relations with automatic schema inference.

  Drops.Relation automatically introspects database tables and generates Ecto schemas,
  providing a convenient query API that delegates to Ecto.Repo functions. Relations
  support composable queries, custom query definitions, and views.

  ## Basic Usage

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)
      end

      # Reading data
      user = MyApp.Users.get(1)
      users = MyApp.Users.all()
      active_users = MyApp.Users.all_by(active: true)

      # Writing data
      {:ok, user} = MyApp.Users.insert(%{name: "John", email: "john@example.com"})
      {:ok, user} = MyApp.Users.update(user, %{name: "Jane"})

  ## Composable Queries

      # Chain operations together
      users = MyApp.Users
              |> MyApp.Users.restrict(active: true)
              |> MyApp.Users.order(:name)
              |> Enum.to_list()

  ## Custom Queries

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)

        defquery active() do
          from(u in relation(), where: u.active == true)
        end

        defquery by_name(name) do
          from(u in relation(), where: u.name == ^name)
        end
      end

      # Use custom queries
      active_users = MyApp.Users.active() |> Enum.to_list()
      john = MyApp.Users.by_name("John") |> MyApp.Users.one()

  ## Configuration

  Relations can be configured at the application level:

      config :my_app, :drops,
        relation: [
          repo: MyApp.Repo,
          default_plugins: [...]
        ]

  All query functions accept an optional `:repo` option to override the default repository.
  """

  alias Drops.Relation.Compilation
  alias __MODULE__

  @doc """
  Macro for defining relation modules with automatic schema inference and query capabilities.

  This macro sets up a complete relation module by configuring plugins, establishing
  database connections, and providing a unified API for database operations. It
  automatically introspects database tables and generates Ecto schemas with
  composable query functions.

  ## Parameters

  - `opts` - Configuration options for the relation module

  ## Options

  - `:repo` - The Ecto repository module to use for database operations (required)
  - `:plugins` - List of plugin modules to include (optional, defaults to configured plugins)
  - `:source` - Source relation module for creating views or derived relations (optional)
  - `:view` - View name when creating relation views (optional)

  ## Generated Functions

  When you use this macro, it generates several functions in your module:
  - `opts/0` - Returns the complete configuration options
  - `opts/1` - Returns a specific configuration option by name
  - `__config__/0` - Returns the relation configuration
  - `source/0` - Returns the source relation (for views)
  - `name/0` - Returns the view name (for views)

  ## Examples

      # Basic relation definition
      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)
      end

      # Relation with custom plugins
      defmodule MyApp.Posts do
        use Drops.Relation,
          repo: MyApp.Repo,
          plugins: [
            Drops.Relation.Plugins.Schema,
            Drops.Relation.Plugins.Reading,
            MyApp.CustomPlugin
          ]

        schema("posts", infer: true)
      end

      # Creating a view relation
      defmodule MyApp.ActiveUsers do
        use MyApp.Users, view: "active_users"

        schema("users", infer: true) do
          # Additional customizations for the view
        end
      end

  ## Plugin System

  The macro automatically includes configured plugins that provide functionality:
  - `Schema` - Automatic Ecto schema generation from database introspection
  - `Reading` - Query functions like `all/0`, `get/1`, `restrict/2`, etc.
  - `Writing` - Insert, update, delete operations
  - `Queryable` - Composable query operations
  - `Views` - Support for database views and derived relations

  ## Configuration

  Relations can be configured at the application level:

      config :my_app, :drops,
        relation: [
          default_plugins: [...],
          schema_module: MyApp.CustomSchemaModule
        ]

  ## Compilation Process

  The macro performs these steps during compilation:
  1. Expands and validates the provided options
  2. Sets up the compilation context with configuration
  3. Loads and applies the specified plugins
  4. Generates helper functions for accessing configuration
  5. Sets up delegation functions for plugin operations
  """
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

      @opts Keyword.put(unquote(opts), :repo, @config[:repo] || unquote(opts[:repo]))
      def opts, do: @opts
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

  ## Behavior

  The macro automatically:
  1. Extracts the function name and arguments from the call pattern
  2. Adds `[relation: __MODULE__]` as the final argument to the delegation
  3. Generates a function definition that calls the target module

  ## Examples

      # In a plugin module
      delegate_to(get(id), to: Reading)
      # Generates:
      # def get(id), do: Reading.get(id, [relation: __MODULE__])

      delegate_to(all(), to: Reading)
      # Generates:
      # def all(), do: Reading.all([relation: __MODULE__])

      delegate_to(restrict(spec), to: Reading)
      # Generates:
      # def restrict(spec), do: Reading.restrict(spec, [relation: __MODULE__])

  ## Generated Function Signature

  For a delegation like `delegate_to(function_name(arg1, arg2), to: Target)`,
  the generated function will be:

      def function_name(arg1, arg2) do
        Target.function_name(arg1, arg2, [relation: __MODULE__])
      end

  ## Plugin Integration

  This macro is primarily used by plugins to create seamless APIs. The injected
  relation context allows plugin functions to access:
  - The relation's repository configuration
  - The relation's schema information
  - The relation's compilation context
  - Any relation-specific options

  ## Usage in Plugins

      defmodule MyPlugin do
        use Drops.Relation.Plugin

        def on(:before_compile, _relation, _) do
          quote do
            alias MyPlugin

            delegate_to(my_function(arg), to: MyPlugin)
            delegate_to(another_function(), to: MyPlugin)
          end
        end
      end
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

  defp plugins(opts) do
    case opts[:plugins] do
      nil ->
        Drops.Relation.Config.default_plugins(opts[:repo])

      plugins when is_list(plugins) ->
        plugins
    end
  end
end
