defmodule Drops.Relation.Plugin do
  alias Drops.Relation.Compilation

  alias __MODULE__

  defmacro __using__(opts) do
    quote location: :keep do
      import Plugin

      @before_compile Plugin

      @opts unquote(opts)
      def opts, do: @opts

      Module.register_attribute(__MODULE__, :dsl, accumulate: false)

      defmacro __before_compile__(env) do
        plugin = __MODULE__
        relation = env.module
        attributes = get_attributes(relation)

        code = plugin.on(:before_compile, relation, attributes)

        quote location: :keep do
          unquote(code)
        end
      end

      defmacro __after_compile__(env, _) do
        plugin = __MODULE__
        relation = env.module
        attributes = get_attributes(relation)

        code = plugin.on(:after_compile, relation, attributes)

        quote location: :keep do
          unquote(code)
        end
      end

      defmacro __using__(_opts) do
        plugin = __MODULE__

        functions = Keyword.get(plugin.opts(), :imports, [])

        imports =
          if functions != [] do
            quote do
              import unquote(plugin), only: unquote(functions)
            end
          else
            []
          end

        setup =
          quote do
            @plugins unquote(plugin)

            @before_compile unquote(plugin)
            @after_compile unquote(plugin)
          end

        quote do
          unquote(imports)
          unquote(setup)
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def on(_event, _relation, _attributes), do: []

      def dsl, do: @dsl || []
    end
  end

  def get_attributes(relation) do
    Enum.reduce(Module.attributes_in(relation), %{}, fn key, acc ->
      Map.put(acc, key, Module.get_attribute(relation, key))
    end)
  end

  def update_context(relation, key, value) do
    Compilation.Context.update(relation, key, value)
  end

  def context(relation, key) do
    Compilation.Context.get(relation, key)
  end

  def config(args, key) do
    Compilation.Context.config(args, key)
  end
end
