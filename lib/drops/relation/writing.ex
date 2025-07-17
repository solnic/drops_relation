defmodule Drops.Relation.Writing do
  @doc """
  Inserts a struct, changeset, or plain map.

  Delegates to `Ecto.Repo.insert/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {:ok, user} = MyRelation.insert(%{name: "John", email: "john@example.com"})
      {:ok, user} = MyRelation.insert(changeset, repo: AnotherRepo)

  See [Ecto.Repo.insert/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert/2) for more details.
  """
  def insert(struct_or_changeset, opts) do
    actual_struct =
      case struct_or_changeset do
        %{__struct__: _} ->
          struct_or_changeset

        %{} = plain_map ->
          struct(opts[:relation].__schema_module__(), plain_map)
      end

    opts[:relation].opts(:repo).insert(actual_struct, Keyword.delete(opts, :relation))
  end

  @doc """
  Inserts a struct, changeset, or plain map, raises on error.

  Delegates to `Ecto.Repo.insert!/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.insert!(%{name: "John", email: "john@example.com"})
      user = MyRelation.insert!(changeset, repo: AnotherRepo)

  See [Ecto.Repo.insert!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert!/2) for more details.
  """
  def insert!(struct_or_changeset, opts) do
    actual_struct =
      case struct_or_changeset do
        %{__struct__: _} ->
          struct_or_changeset

        %{} = plain_map ->
          struct(opts[:relation].__schema_module__(), plain_map)
      end

    opts[:relation].opts(:repo).insert!(actual_struct, Keyword.delete(opts, :relation))
  end

  @doc """
  Updates a changeset.

  Delegates to `Ecto.Repo.update/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {:ok, user} = MyRelation.update(changeset)
      {:ok, user} = MyRelation.update(changeset, repo: AnotherRepo)

  See [Ecto.Repo.update/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update/2) for more details.
  """
  def update(changeset, opts) do
    opts[:relation].opts(:repo).update(changeset, Keyword.delete(opts, :relation))
  end

  @doc """
  Updates a changeset, raises on error.

  Delegates to `Ecto.Repo.update!/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.update!(changeset)
      user = MyRelation.update!(changeset, repo: AnotherRepo)

  See [Ecto.Repo.update!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update!/2) for more details.
  """
  def update!(changeset, opts) do
    opts[:relation].opts(:repo).update!(changeset, Keyword.delete(opts, :relation))
  end

  @doc """
  Deletes a struct.

  Delegates to `Ecto.Repo.delete/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {:ok, user} = MyRelation.delete(user)
      {:ok, user} = MyRelation.delete(user, repo: AnotherRepo)

  See [Ecto.Repo.delete/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete/2) for more details.
  """
  def delete(struct, opts) do
    opts[:relation].opts(:repo).delete(struct, Keyword.delete(opts, :relation))
  end

  @doc """
  Deletes a struct, raises on error.

  Delegates to `Ecto.Repo.delete!/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.delete!(user)
      user = MyRelation.delete!(user, repo: AnotherRepo)

  See [Ecto.Repo.delete!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete!/2) for more details.
  """
  def delete!(struct, opts) do
    opts[:relation].opts(:repo).delete!(struct, Keyword.delete(opts, :relation))
  end
end
