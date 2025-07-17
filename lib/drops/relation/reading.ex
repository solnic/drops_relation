defmodule Drops.Relation.Reading do
  # Query API functions - these are defined at module level for proper documentation
  # and delegate to Ecto.Repo functions with the configured repository

  @doc """
  Gets a single record by primary key.

  Delegates to `Ecto.Repo.get/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get(1)
      user = MyRelation.get(1, repo: AnotherRepo)

  See [Ecto.Repo.get/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get/3) for more details.
  """
  def get(id, opts) do
    opts[:relation].opts(:repo).get(opts[:relation], id, Keyword.delete(opts, :relation))
  end

  @doc """
  Gets a single record by primary key, raises if not found.

  Delegates to `Ecto.Repo.get!/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get!(1)
      user = MyRelation.get!(1, repo: AnotherRepo)

  See [Ecto.Repo.get!/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get!/3) for more details.
  """
  def get!(id, opts) do
    opts[:relation].opts(:repo).get!(opts[:relation], id, Keyword.delete(opts, :relation))
  end

  @doc """
  Gets a single record by the given clauses.

  Delegates to `Ecto.Repo.get_by/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get_by(email: "user@example.com")
      user = MyRelation.get_by([email: "user@example.com"], repo: AnotherRepo)

  See [Ecto.Repo.get_by/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get_by/3) for more details.
  """
  def get_by(clauses, opts) do
    opts[:relation].opts(:repo).get_by(opts[:relation], clauses, Keyword.delete(opts, :relation))
  end

  @doc """
  Gets a single record by the given clauses, raises if not found.

  Delegates to `Ecto.Repo.get_by!/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get_by!(email: "user@example.com")
      user = MyRelation.get_by!([email: "user@example.com"], repo: AnotherRepo)

  See [Ecto.Repo.get_by!/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get_by!/3) for more details.
  """
  def get_by!(clauses, opts) do
    opts[:relation].opts(:repo).get_by!(opts[:relation], clauses, Keyword.delete(opts, :relation))
  end

  @doc """
  Fetches all records matching the given query.

  Delegates to `Ecto.Repo.all/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      users = MyRelation.all()
      users = MyRelation.all(repo: AnotherRepo)

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more details.
  """
  def all(opts) when is_list(opts) do
    opts[:relation].opts(:repo).all(opts[:relation], Keyword.delete(opts, :relation))
  end

  def all(%{__struct__: relation_module} = relation) do
    # When called with a relation struct, use the Ecto.Queryable protocol
    repo = relation.repo || relation_module.opts(:repo)
    repo.all(relation, [])
  end

  @doc """
  Fetches a single result from the query.

  Delegates to `Ecto.Repo.one/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.one(query)
      user = MyRelation.one(query, repo: AnotherRepo)

  See [Ecto.Repo.one/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) for more details.
  """
  def one(opts) do
    opts[:relation].opts(:repo).one(opts[:relation], Keyword.delete(opts, :relation))
  end

  @doc """
  Fetches a single result from the query, raises if not found or more than one.

  Delegates to `Ecto.Repo.one!/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.one!(query)
      user = MyRelation.one!(query, repo: AnotherRepo)

  See [Ecto.Repo.one!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one!/2) for more details.
  """
  def one!(opts) do
    opts[:relation].opts(:repo).one!(opts[:relation], Keyword.delete(opts, :relation))
  end

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

  @doc """
  Returns the count of records.

  Delegates to `Ecto.Repo.aggregate/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      count = MyRelation.count()
      count = MyRelation.count(repo: AnotherRepo)

  See [Ecto.Repo.aggregate/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/3) for more details.
  """
  def count(opts) do
    opts[:relation].opts(:repo).aggregate(
      opts[:relation],
      :count,
      Keyword.delete(opts, :relation)
    )
  end

  @doc """
  Returns the first record.

  Delegates to `Ecto.Repo.one/2` with `Ecto.Query.first/1`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.first()
      user = MyRelation.first(repo: AnotherRepo)

  See [Ecto.Repo.one/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) and
  [Ecto.Query.first/1](https://hexdocs.pm/ecto/Ecto.Query.html#first/1) for more details.
  """
  def first(opts) do
    opts[:relation].opts(:repo).one(
      Ecto.Query.first(opts[:relation]),
      Keyword.delete(opts, :relation)
    )
  end

  @doc """
  Returns the last record.

  Delegates to `Ecto.Repo.one/2` with `Ecto.Query.last/1`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.last()
      user = MyRelation.last(repo: AnotherRepo)

  See [Ecto.Repo.one/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) and
  [Ecto.Query.last/1](https://hexdocs.pm/ecto/Ecto.Query.html#last/1) for more details.
  """
  def last(opts) do
    opts[:relation].opts(:repo).one(
      Ecto.Query.last(opts[:relation]),
      Keyword.delete(opts, :relation)
    )
  end

  @doc """
  Gets a record by a specific field value.

  This is a generic function used by dynamically generated index-based finders.
  Delegates to `Ecto.Repo.get_by/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get_by_field(:email, "user@example.com")
      user = MyRelation.get_by_field(:email, "user@example.com", repo: AnotherRepo)

  See [Ecto.Repo.get_by/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get_by/3) for more details.
  """
  def get_by_field(field, value, opts) do
    opts[:relation].opts(:repo).get_by(
      opts[:relation],
      [{field, value}],
      Keyword.delete(opts, :relation)
    )
  end
end
