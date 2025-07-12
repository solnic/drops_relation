defmodule Drops.Relation.Composite do
  @moduledoc """
  Represents a composite relation that combines two different relation types
  with automatic preloading of associations.

  This module enables composition like:

      Users.restrict(admin: true) |> Posts.restrict(published: true)

  Where the result automatically preloads the :posts association for Users.

  ## Structure

  A Composite relation has:
  - `left` - The primary relation (e.g., restricted Users)
  - `right` - The secondary relation (e.g., restricted Posts)
  - `association` - The association name to preload (e.g., :posts)
  - `repo` - The repository to use for queries
  """

  @type t :: %__MODULE__{
          left: struct(),
          right: struct(),
          association: atom(),
          repo: module()
        }

  defstruct [:left, :right, :association, :repo]

  @doc """
  Creates a new Composite relation.

  ## Parameters

  - `left` - The primary relation
  - `right` - The secondary relation
  - `association` - The association name to preload
  - `repo` - The repository module

  ## Examples

      composite = Drops.Relation.Composite.new(
        users_relation,
        posts_relation,
        :posts,
        MyApp.Repo
      )
  """
  @spec new(struct(), struct(), atom(), module()) :: t()
  def new(left, right, association, repo) do
    %__MODULE__{
      left: left,
      right: right,
      association: association,
      repo: repo
    }
  end

  @doc """
  Determines the association name between two relation modules.

  This function analyzes the associations of the left relation to find
  which association corresponds to the right relation's table.

  ## Examples

      association = Drops.Relation.Composite.infer_association(Users, Posts)
      # => :posts
  """
  @spec infer_association(module(), module()) :: atom() | nil
  def infer_association(left_module, right_module) do
    left_associations = left_module.associations()
    right_source = right_module.ecto_schema(:source)

    # Find association that matches the right relation's table
    Enum.find_value(left_associations, fn assoc_name ->
      association = left_module.association(assoc_name)

      case association do
        %{queryable: queryable} when is_atom(queryable) ->
          if queryable.__schema__(:source) == right_source do
            assoc_name
          end

        _ ->
          nil
      end
    end)
  end
end

defimpl Ecto.Queryable, for: Drops.Relation.Composite do
  import Ecto.Query

  def to_query(composite) do
    # Get the base query from the left relation
    left_query = Ecto.Queryable.to_query(composite.left)

    # Get the right relation query for filtering the association
    right_query = Ecto.Queryable.to_query(composite.right)

    # Build a query that preloads the association with the right relation's restrictions
    from(l in left_query,
      preload: [{^composite.association, ^right_query}]
    )
  end
end

defimpl Enumerable, for: Drops.Relation.Composite do
  def count(composite) do
    {:ok, length(materialize(composite))}
  end

  def member?(composite, value) do
    case materialize(composite) do
      {:ok, list} -> {:ok, value in list}
      {:error, _} = error -> error
    end
  end

  def slice(composite) do
    list = materialize(composite)
    size = length(list)

    {:ok, size, fn start, count, _step -> Enum.slice(list, start, count) end}
  end

  def reduce(composite, acc, fun) do
    Enumerable.List.reduce(materialize(composite), acc, fun)
  end

  defp materialize(composite) do
    query = Ecto.Queryable.to_query(composite)
    composite.repo.all(query)
  end
end
