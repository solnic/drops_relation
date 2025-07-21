defmodule Drops.Relation.Plugins.Queryable.InvalidQueryError do
  @moduledoc """
  Exception raised when a queryable operation contains validation errors.

  This exception is raised when query compilers detect invalid operations
  such as comparing nil values to non-nullable fields, using undefined
  associations in preloads, or other validation failures.

  ## Examples

      # Raised when trying to compare nil to a non-nullable field
      raise InvalidQueryError, errors: ["name is not nullable, comparing to `nil` is not allowed"]

      # Raised when trying to preload a non-defined association
      raise InvalidQueryError, errors: ["association :invalid_assoc is not defined"]
  """

  defexception [:errors]

  @type t :: %__MODULE__{
          errors: [String.t()]
        }

  @doc """
  Creates a new InvalidQueryError with the given errors.

  ## Parameters

  - `errors` - A list of human-readable error messages

  ## Examples

      iex> InvalidQueryError.new(["field is not nullable"])
      %InvalidQueryError{errors: ["field is not nullable"]}
  """
  @spec new([String.t()]) :: t()
  def new(errors) when is_list(errors) do
    %__MODULE__{errors: errors}
  end

  @doc """
  Returns a human-readable error message for the exception.

  ## Examples

      iex> error = InvalidQueryError.new(["name is not nullable", "invalid association"])
      iex> InvalidQueryError.message(error)
      "Query validation failed:\\n  - name is not nullable\\n  - invalid association"
  """
  @impl Exception
  def message(%__MODULE__{errors: errors}) when is_list(errors) do
    case errors do
      [] ->
        "Query validation failed with unknown errors"

      [single_error] ->
        "Query validation failed: #{single_error}"

      multiple_errors ->
        formatted_errors =
          multiple_errors
          |> Enum.map(&"  - #{&1}")
          |> Enum.join("\n")

        "Query validation failed:\n#{formatted_errors}"
    end
  end
end
