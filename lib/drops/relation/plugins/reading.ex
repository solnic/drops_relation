defmodule Drops.Relation.Plugins.Reading do
  use Drops.Relation.Plugin

  def on(:before_compile, _relation, _) do
    quote do
      alias unquote(__MODULE__)

      delegate_to(get(id), to: Reading)
      delegate_to(get!(id), to: Reading)
      delegate_to(get_by(clauses), to: Reading)
      delegate_to(get_by!(clauses), to: Reading)
      delegate_to(all_by(clauses), to: Reading)
      delegate_to(one(), to: Reading)
      delegate_to(one!(), to: Reading)
      delegate_to(count(), to: Reading)
      delegate_to(first(), to: Reading)
      delegate_to(last(), to: Reading)
      delegate_to(exists?(), to: Reading)
      delegate_to(stream(), to: Reading)
      delegate_to(aggregate(aggregate), to: Reading)
      delegate_to(aggregate(aggregate, field), to: Reading)
      delegate_to(delete_all(), to: Reading)
      delegate_to(update_all(updates), to: Reading)
      delegate_to(transaction(fun_or_multi), to: Reading)
      delegate_to(in_transaction?(), to: Reading)
      delegate_to(checkout(fun), to: Reading)

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
        add_operation(new(), :restrict, opts)
      end

      def restrict(%__MODULE__{} = relation, opts) do
        add_operation(relation, :restrict, opts)
      end

      def restrict(queryable, opts) do
        add_operation(new(queryable, []), :restrict, opts)
      end

      def preload(association) when is_atom(association) do
        add_operation(new(), :preload, [association])
      end

      def preload(%__MODULE__{} = relation, association) when is_atom(association) do
        preload(relation, [association])
      end

      def preload(associations) when is_list(associations) do
        add_operation(new(), :preload, associations)
      end

      def preload(%__MODULE__{} = relation, associations) when is_list(associations) do
        add_operation(relation, :preload, associations)
      end

      def order(opts) when is_atom(opts) or is_list(opts) do
        add_operation(new(), :order, opts)
      end

      def order(%__MODULE__{} = relation, opts) when is_atom(opts) or is_list(opts) do
        add_operation(relation, :order, opts)
      end

      def order(queryable, opts) when is_atom(opts) or is_list(opts) do
        add_operation(new(queryable, []), :order, opts)
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
    read(:get, [id], opts)
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
    read(:get!, [id], opts)
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
    read(:get_by, [clauses], opts)
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
    read(:get_by!, [clauses], opts)
  end

  @doc """
  Fetches all records matching the given clauses.

  Delegates to `Ecto.Repo.all/2` with a where clause. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      users = MyRelation.all_by(active: true)
      users = MyRelation.all_by([active: true], repo: AnotherRepo)

  See [Ecto.Repo.all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more details.
  """
  def all_by(clauses, opts) do
    # Use the same approach as get_by but return all results
    relation = opts[:relation]
    repo = relation.repo()
    queryable = relation.new()
    repo_opts = Keyword.delete(opts, :relation)

    # Build query with where conditions
    import Ecto.Query
    query = from(q in queryable, where: ^clauses)

    apply(repo, :all, [query, repo_opts])
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
    read(:all, [], opts)
  end

  def all(%{__struct__: relation_module} = relation) do
    read(:all, [], relation: relation_module, queryable: relation)
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
    read(:one, [], opts)
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
    read(:one!, [], opts)
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
    read(:aggregate, [:count], opts)
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
    read(:one, [], Keyword.merge(opts, queryable: Ecto.Query.first(opts[:relation])))
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
    read(:one, [], Keyword.merge(opts, queryable: Ecto.Query.last(opts[:relation])))
  end

  @doc """
  Checks if any entry matches the given query.

  Delegates to `Ecto.Repo.exists?/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      exists = MyRelation.exists?()
      exists = MyRelation.exists?(repo: AnotherRepo)

  See [Ecto.Repo.exists?/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:exists?/2) for more details.
  """
  def exists?(opts) do
    read(:exists?, [], opts)
  end

  @doc """
  Returns a lazy enumerable that emits all entries from the data store.

  Delegates to `Ecto.Repo.stream/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      stream = MyRelation.stream()
      stream = MyRelation.stream(repo: AnotherRepo)

  See [Ecto.Repo.stream/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:stream/2) for more details.
  """
  def stream(opts) do
    read(:stream, [], opts)
  end

  @doc """
  Calculates the given aggregate.

  Delegates to `Ecto.Repo.aggregate/3` or `Ecto.Repo.aggregate/4`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      count = MyRelation.aggregate(:count)
      avg_age = MyRelation.aggregate(:avg, :age)
      max_id = MyRelation.aggregate(:max, :id, repo: AnotherRepo)

  See [Ecto.Repo.aggregate/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/3) and
  [Ecto.Repo.aggregate/4](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4) for more details.
  """
  def aggregate(aggregate, opts) do
    read(:aggregate, [aggregate], opts)
  end

  def aggregate(aggregate, field, opts) do
    read(:aggregate, [aggregate, field], opts)
  end

  @doc """
  Deletes all entries matching the given query.

  Delegates to `Ecto.Repo.delete_all/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {count, _} = MyRelation.delete_all()
      {count, _} = MyRelation.delete_all(repo: AnotherRepo)

  See [Ecto.Repo.delete_all/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete_all/2) for more details.
  """
  def delete_all(opts) do
    read(:delete_all, [], opts)
  end

  @doc """
  Updates all entries matching the given query with the given values.

  Delegates to `Ecto.Repo.update_all/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {count, _} = MyRelation.update_all(set: [active: false])
      {count, _} = MyRelation.update_all([set: [active: false]], repo: AnotherRepo)

  See [Ecto.Repo.update_all/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update_all/3) for more details.
  """
  def update_all(updates, opts) do
    read(:update_all, [updates], opts)
  end

  @doc """
  Runs the given function or Ecto.Multi inside a transaction.

  Delegates to `Ecto.Repo.transaction/2`. The `:repo` option is automatically set
  based on the repository configured in the `use` macro, but can be overridden.

  ## Examples

      {:ok, result} = MyRelation.transaction(fn ->
        # database operations
      end)

      {:ok, changes} = MyRelation.transaction(multi, repo: AnotherRepo)

  See [Ecto.Repo.transaction/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2) for more details.
  """
  def transaction(fun_or_multi, opts) do
    relation = opts[:relation]
    repo = relation.repo()
    repo_opts = Keyword.delete(opts, :relation)

    apply(repo, :transaction, [fun_or_multi, repo_opts])
  end

  @doc """
  Returns true if the current process is inside a transaction.

  Delegates to `Ecto.Repo.in_transaction?/0`. The `:repo` option is automatically set
  based on the repository configured in the `use` macro, but can be overridden.

  ## Examples

      in_tx = MyRelation.in_transaction?()

  See [Ecto.Repo.in_transaction?/0](https://hexdocs.pm/ecto/Ecto.Repo.html#c:in_transaction?/0) for more details.
  """
  def in_transaction?(opts) do
    relation = opts[:relation]
    repo = relation.repo()

    apply(repo, :in_transaction?, [])
  end

  @doc """
  Checks out a connection for the duration of the function.

  Delegates to `Ecto.Repo.checkout/2`. The `:repo` option is automatically set
  based on the repository configured in the `use` macro, but can be overridden.

  ## Examples

      result = MyRelation.checkout(fn ->
        # database operations with checked out connection
      end)

  See [Ecto.Repo.checkout/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:checkout/2) for more details.
  """
  def checkout(fun, opts) do
    relation = opts[:relation]
    repo = relation.repo()
    repo_opts = Keyword.delete(opts, :relation)

    apply(repo, :checkout, [fun, repo_opts])
  end

  defp read(fun, args, opts) do
    relation = opts[:relation]
    repo = relation.repo()
    queryable = Keyword.get(opts, :queryable) || relation.new()
    repo_opts = Keyword.delete(opts, :relation) |> Keyword.delete(:queryable)

    apply(repo, fun, [queryable] ++ args ++ [repo_opts])
  end
end
