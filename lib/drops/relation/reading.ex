defmodule Drops.Relation.Reading do
  defmacro __using__(_opts) do
    quote do
      alias unquote(__MODULE__)

      delegate_to(get(id), to: Reading)
      delegate_to(get!(id), to: Reading)
      delegate_to(get_by(clauses), to: Reading)
      delegate_to(get_by!(clauses), to: Reading)
      delegate_to(one(), to: Reading)
      delegate_to(one!(), to: Reading)
      delegate_to(count(), to: Reading)
      delegate_to(first(), to: Reading)
      delegate_to(last(), to: Reading)

      def all(relation_or_opts \\ [])

      def all([]) do
        Reading.all(relation: __MODULE__)
      end

      def all(opts) when is_list(opts) do
        Reading.all(opts |> Keyword.put(:relation, __MODULE__))
      end

      def all(%__MODULE__{} = relation) do
        Reading.all(relation)
      end

      def restrict(opts) when is_list(opts) do
        new(opts)
      end

      def restrict(%__MODULE__{} = relation, opts) do
        %{relation | opts: Keyword.merge(relation.opts, opts)}
      end

      def restrict(queryable, opts) do
        new(queryable, opts)
      end

      def preload(association) when is_atom(association) do
        preload(new(), [association])
      end

      def preload(%__MODULE__{} = relation, association) when is_atom(association) do
        preload(relation, [association])
      end

      def preload(%__MODULE__{} = relation, associations) when is_list(associations) do
        %{relation | preloads: relation.preloads ++ associations}
      end
    end
  end

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
