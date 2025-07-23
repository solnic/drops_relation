defmodule Drops.Relation.Plugins.Queryable.Operations.Compiler do
  @moduledoc false

  @callback visit(map(), map()) :: {:ok, Ecto.Query.t()} | {:error, [String.t()]}

  defmodule Result do
    @moduledoc false

    defstruct [:query, errors: []]

    def new(query), do: %__MODULE__{query: query}

    def to_success(result), do: {:ok, result.query}

    def to_error(result), do: {:error, Enum.reverse(result.errors)}
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      alias unquote(__MODULE__.Result)

      import Ecto.Query
      import unquote(__MODULE__)

      def visit({nil, _value}, %{key: key}), do: error(:field_not_found, key)
      def visit(nil, %{key: key}), do: error(:field_not_found, key)
    end
  end

  def error(:field_not_found, field_name) when is_atom(field_name) do
    error("Field '#{field_name}' not found in schema")
  end

  def error(:invalid_value, %{field: field_name, value: value}) do
    error("Invalid value '#{inspect(value)}' for field '#{field_name}'")
  end

  def error(:not_nullable, field_name) when is_atom(field_name) do
    error("#{field_name} is not nullable, comparing to `nil` is not allowed")
  end

  def error(:not_boolean_field, %{field: field_name, value: value}) do
    error(
      "#{field_name} is not a boolean field, comparing to boolean value `#{value}` is not allowed"
    )
  end

  def error(:custom, message) do
    error(message)
  end

  def error(message) when is_binary(message) do
    {:error, message}
  end
end
