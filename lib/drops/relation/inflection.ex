defmodule Drops.Relation.Inflection do
  @moduledoc """
  Simple inflection utilities for Drops.Relation.

  This module provides basic inflection functions for converting between
  singular and plural forms, similar to how Ecto handles association keys.
  """

  @doc """
  Converts a plural word to its singular form.

  This is a basic implementation that handles common English pluralization rules.
  For more complex inflection needs, consider using a dedicated inflection library.

  ## Examples

      iex> Drops.Relation.Inflection.singularize("users")
      "user"

      iex> Drops.Relation.Inflection.singularize("categories")
      "category"

      iex> Drops.Relation.Inflection.singularize("children")
      "child"

      iex> Drops.Relation.Inflection.singularize("people")
      "person"
  """
  @spec singularize(String.t()) :: String.t()
  def singularize(word) when is_binary(word) do
    # Handle irregular plurals first
    case irregular_singulars()[word] do
      nil -> apply_singularization_rules(word)
      singular -> singular
    end
  end

  @doc """
  Converts a module name to a schema name using proper inflection.

  This function takes a module name, extracts the last part, converts it to
  underscore case, and singularizes it.

  ## Examples

      iex> Drops.Relation.Inflection.module_to_schema_name(MyApp.Users)
      "user"

      iex> Drops.Relation.Inflection.module_to_schema_name(MyApp.BlogPosts)
      "blog_post"

      iex> Drops.Relation.Inflection.module_to_schema_name(MyApp.UserCategories)
      "user_category"
  """
  @spec module_to_schema_name(module()) :: String.t()
  def module_to_schema_name(module) when is_atom(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> singularize()
    |> Macro.camelize()
  end

  # Private functions

  # Common irregular plural to singular mappings
  defp irregular_singulars do
    %{
      "children" => "child",
      "feet" => "foot",
      "geese" => "goose",
      "men" => "man",
      "mice" => "mouse",
      "people" => "person",
      "teeth" => "tooth",
      "women" => "woman",
      "oxen" => "ox",
      # Words that should not be singularized
      "news" => "news",
      "data" => "data",
      "information" => "information",
      "equipment" => "equipment",
      "series" => "series",
      "species" => "species",
      "fish" => "fish",
      "sheep" => "sheep",
      "deer" => "deer"
    }
  end

  # Apply standard singularization rules
  defp apply_singularization_rules(word) do
    cond do
      # Words ending in 'ies' -> 'y' (e.g., categories -> category)
      String.ends_with?(word, "ies") ->
        String.slice(word, 0..-4//1) <> "y"

      # Words ending in 'ves' -> 'f' or 'fe' (e.g., wolves -> wolf, lives -> life)
      String.ends_with?(word, "ves") ->
        base = String.slice(word, 0..-4//1)

        if String.ends_with?(base, "l") or String.ends_with?(base, "r") do
          base <> "f"
        else
          base <> "fe"
        end

      # Words ending in 'ses' -> 's' (e.g., glasses -> glass)
      String.ends_with?(word, "ses") ->
        String.slice(word, 0..-3//1)

      # Words ending in 'ches' -> 'ch' (e.g., watches -> watch)
      String.ends_with?(word, "ches") ->
        String.slice(word, 0..-3//1)

      # Words ending in 'shes' -> 'sh' (e.g., dishes -> dish)
      String.ends_with?(word, "shes") ->
        String.slice(word, 0..-3//1)

      # Words ending in 'xes' -> 'x' (e.g., boxes -> box)
      String.ends_with?(word, "xes") ->
        String.slice(word, 0..-3//1)

      # Words ending in 'zzes' -> 'z' (e.g., quizzes -> quiz)
      String.ends_with?(word, "zzes") ->
        String.slice(word, 0..-4//1)

      # Words ending in 'zes' -> 'ze' (e.g., prizes -> prize)
      String.ends_with?(word, "zes") ->
        String.slice(word, 0..-2//1)

      # Words ending in 'es' after consonant + 'o' -> 'o' (e.g., heroes -> hero)
      String.ends_with?(word, "oes") ->
        String.slice(word, 0..-3//1)

      # Words ending in 's' but not 'ss' -> remove 's' (e.g., users -> user)
      String.ends_with?(word, "s") and not String.ends_with?(word, "ss") ->
        String.slice(word, 0..-2//1)

      # If no rules match, return the word as-is
      true ->
        word
    end
  end
end
