defmodule Drops.Relation.Plugins.Reading do
  @moduledoc """
  Plugin that provides reading operations for relation modules.

  This plugin adds Ecto.Repo-like functions for querying data, organized into two main groups:

  ## Query API

  These functions execute queries immediately and return results. They delegate directly to
  the corresponding Ecto.Repo functions with automatic repository and relation configuration:

  - Basic CRUD operations (`get/2`, `all/1`, `get_by/2`, etc.)
  - Aggregation functions (`count/1`, `aggregate/2`)
  - Transaction support (`transaction/2`, `checkout/2`)
  - Utility functions (`exists?/1`, `stream/1`, etc.)

  ## Composable Query API

  These functions build composable query operations that can be chained together and
  executed later. They return relation structs that can be further composed:

  - `restrict/2` - Add WHERE conditions to filter records
  - `order/2` - Add ORDER BY clauses to sort records
  - `preload/2` - Add association preloading

  ## Key Differences

  **Query API functions** execute immediately:
  ```elixir
  users = Users.all()                    # Returns list of users
  user = Users.get(1)                    # Returns user or nil
  count = Users.count()                  # Returns integer
  ```

  **Composable Query API functions** return composable relations:
  ```elixir
  query = Users.restrict(active: true)   # Returns relation struct
  query = Users.order(query, :name)      # Returns relation struct
  users = Users.all(query)               # Execute and return results
  ```

  ## Examples

      # Query API - immediate execution
      user = Users.get(1)
      users = Users.all()
      user = Users.get_by(email: "john@example.com")
      count = Users.count()
      avg_age = Users.aggregate(:avg, :age)

      # Composable Query API - build and execute
      active_users = Users
                     |> Users.restrict(active: true)
                     |> Users.order(:name)
                     |> Users.all()

      # Mixed usage
      base_query = Users.restrict(active: true)
      admin_users = Users.restrict(base_query, role: "admin")
      sorted_admins = Users.order(admin_users, :name)
      results = Users.all(sorted_admins)
  """

  use Drops.Relation.Plugin

  def on(:before_compile, _relation, _) do
    quote do
      alias unquote(__MODULE__)

      # Ecto.Repo-like interface
      delegate_to(get(id), to: Reading)
      delegate_to(get!(id), to: Reading)
      delegate_to(get_by(clauses), to: Reading)
      delegate_to(get_by!(clauses), to: Reading)
      delegate_to(all(), to: Reading)
      delegate_to(all(opts), to: Reading)
      delegate_to(all_by(clauses), to: Reading)
      delegate_to(one(), to: Reading)
      delegate_to(one(relation), to: Reading)
      delegate_to(one!(), to: Reading)
      delegate_to(one!(relation), to: Reading)
      delegate_to(count(), to: Reading)
      delegate_to(count(relation), to: Reading)
      delegate_to(first(), to: Reading)
      delegate_to(first(relation), to: Reading)
      delegate_to(last(), to: Reading)
      delegate_to(last(relation), to: Reading)
      delegate_to(exists?(), to: Reading)
      delegate_to(stream(), to: Reading)
      delegate_to(aggregate(aggregate), to: Reading)
      delegate_to(aggregate(aggregate, field), to: Reading)
      delegate_to(delete_all(), to: Reading)
      delegate_to(update_all(updates), to: Reading)
      delegate_to(transaction(fun_or_multi), to: Reading)
      delegate_to(in_transaction?(), to: Reading)
      delegate_to(checkout(fun), to: Reading)

      # Aggregation shortcuts
      delegate_to(min(field), to: Reading)
      delegate_to(min(relation, field), to: Reading)
      delegate_to(max(field), to: Reading)
      delegate_to(max(relation, field), to: Reading)
      delegate_to(sum(field), to: Reading)
      delegate_to(sum(relation, field), to: Reading)
      delegate_to(avg(field), to: Reading)
      delegate_to(avg(relation, field), to: Reading)

      # Composable function interface
      delegate_to(restrict(spec), to: Reading)
      delegate_to(restrict(other, spec), to: Reading)
      delegate_to(order(spec), to: Reading)
      delegate_to(order(other, spec), to: Reading)
      delegate_to(preload(spec), to: Reading)
      delegate_to(preload(other, spec), to: Reading)
    end
  end

  @type queryable :: Ecto.Queryable.t()

  @type relation :: %{
          queryable: Ecto.Queryable.t(),
          opts: keyword()
        }

  @type order_spec :: atom() | [atom()] | keyword()

  @type preload_spec :: atom() | [atom()] | keyword()

  @type restrict_spec :: keyword()

  @doc """
  Restricts the query with the given conditions.

  This function creates a composable query operation that adds WHERE conditions
  to filter records. It can be used standalone or chained with other operations.

  ## Parameters

  - `spec` - A keyword list of field-value pairs to filter by
  - `opts` - Additional options (typically empty for composable operations)

  ## Examples

      # Standalone usage
      active_users = Users.restrict(active: true)

      # Chained operations
      result = Users
               |> Users.restrict(active: true)
               |> Users.order(:name)
               |> Users.all()

      # Multiple conditions
      filtered = Users.restrict(active: true, role: "admin")

  ## Returns

  Returns a relation struct that can be further composed or executed.
  """
  @doc group: "Composable Query API"
  @spec restrict(restrict_spec(), keyword()) :: relation()
  def restrict(spec, opts), do: operation(:restrict, Keyword.put(opts, :restrict, spec))

  @doc """
  Restricts the given queryable with the specified conditions.

  This is the two-argument version that takes an existing queryable (relation or query)
  and applies additional restrictions to it.

  ## Parameters

  - `other` - An existing queryable (relation struct or Ecto query)
  - `spec` - A keyword list of field-value pairs to filter by
  - `opts` - Additional options (typically empty for composable operations)

  ## Examples

      # Apply restriction to existing relation
      base_query = Users.order(:name)
      active_users = Users.restrict(base_query, active: true)

      # Chain multiple restrictions
      filtered = Users
                 |> Users.restrict(active: true)
                 |> Users.restrict(role: "admin")

  ## Returns

  Returns a relation struct that can be further composed or executed.
  """
  @doc group: "Composable Query API"
  @spec restrict(queryable(), keyword()) :: relation()
  def restrict(other, spec, opts),
    do: operation(other, :restrict, Keyword.put(opts, :restrict, spec))

  @doc """
  Orders the query by the given specification.

  This function creates a composable query operation that adds ORDER BY clauses
  to sort records. It supports various ordering specifications.

  ## Parameters

  - `spec` - The ordering specification (see examples below)
  - `opts` - Additional options (typically empty for composable operations)

  ## Ordering Specifications

  - `:field` - Order by field in ascending order
  - `[field1, field2]` - Order by multiple fields in ascending order
  - `[asc: :field]` - Explicitly specify ascending order
  - `[desc: :field]` - Order by field in descending order
  - `[asc: :field1, desc: :field2]` - Mixed ordering

  ## Examples

      # Simple ascending order
      ordered = Users.order(:name)

      # Descending order
      recent_first = Users.order(desc: :created_at)

      # Multiple fields
      sorted = Users.order([:last_name, :first_name])

      # Mixed ordering
      complex = Users.order([desc: :created_at, asc: :name])

      # Chained with other operations
      result = Users
               |> Users.restrict(active: true)
               |> Users.order(:name)
               |> Users.all()

  ## Returns

  Returns a relation struct that can be further composed or executed.
  """
  @doc group: "Composable Query API"
  @spec order(order_spec(), keyword()) :: relation()
  def order(spec, opts) do
    operation(:order, Keyword.put(opts, :order, spec))
  end

  @doc """
  Orders the given queryable by the specified criteria.

  This is the two-argument version that takes an existing queryable (relation or query)
  and applies ordering to it.

  ## Parameters

  - `other` - An existing queryable (relation struct or Ecto query)
  - `spec` - The ordering specification (see `order/2` for details)
  - `opts` - Additional options (typically empty for composable operations)

  ## Examples

      # Apply ordering to existing relation
      base_query = Users.restrict(active: true)
      ordered = Users.order(base_query, :name)

      # Chain multiple orderings (last one takes precedence)
      sorted = Users
               |> Users.order(:created_at)
               |> Users.order(:name)  # This will be the final ordering

  ## Returns

  Returns a relation struct that can be further composed or executed.
  """
  @doc group: "Composable Query API"
  @spec order(queryable(), order_spec(), keyword()) :: relation()
  def order(other, spec, opts) do
    operation(other, :order, Keyword.put(opts, :order, spec))
  end

  @doc """
  Preloads associations in queries.

  This function creates composable query operations that preload the specified
  associations when the query is executed. It supports multiple function signatures
  for different use cases.

  ## Function Signatures

  - `preload(association, opts)` - Preload a single association
  - `preload(associations, opts)` - Preload multiple associations
  - `preload(other, association, opts)` - Preload single association from existing queryable
  - `preload(other, associations, opts)` - Preload multiple associations from existing queryable

  ## Parameters

  - `other` - An existing queryable (relation struct or Ecto query)
  - `association` - A single association name as an atom
  - `associations` - List of association names or nested preload specification
  - `opts` - Additional options (typically empty for composable operations)

  ## Preload Specifications

  - `:assoc` - Preload single association
  - `[:assoc1, :assoc2]` - Preload multiple associations
  - `[assoc: :nested]` - Preload nested associations
  - `[assoc: [:nested1, :nested2]]` - Preload multiple nested associations

  ## Examples

      # Preload single association
      with_posts = Users.preload(:posts)

      # Preload multiple associations
      with_assocs = Users.preload([:posts, :profile])

      # Nested preloads
      nested = Users.preload([posts: :comments])

      # Complex nested preloads
      complex = Users.preload([posts: [:comments, :tags], :profile])

      # Preload from existing query
      base_query = Users.restrict(active: true)
      with_posts = Users.preload(base_query, :posts)

      # Chain with other operations
      result = Users
               |> Users.restrict(active: true)
               |> Users.order(:name)
               |> Users.preload([:posts, :profile])
               |> Users.all()

  ## Returns

  Returns a relation struct that can be further composed or executed.
  """
  @doc group: "Composable Query API"
  @spec preload(queryable(), atom(), keyword()) :: relation()
  def preload(other, association, opts) when is_atom(association) do
    preload(other, [association], opts)
  end

  @spec preload(queryable(), preload_spec(), keyword()) :: relation()
  def preload(other, associations, opts) when is_list(associations) do
    operation(other, :preload, Keyword.put(opts, :preload, associations))
  end

  @doc group: "Composable Query API"
  @spec preload(atom(), keyword()) :: relation()
  def preload(association, opts) when is_atom(association) do
    preload([association], opts)
  end

  @spec preload(preload_spec(), keyword()) :: relation()
  def preload(associations, opts) when is_list(associations) do
    operation(:preload, Keyword.put(opts, :preload, associations))
  end

  # Query API functions - these are defined at module level for proper documentation
  # and delegate to Ecto.Repo functions with the configured repository

  @doc """
  Fetches a single record by its primary key.

  This function retrieves a single record from the database using the primary key value.
  It returns the record if found, or `nil` if no record exists with the given primary key.

  ## Parameters

  - `id` - The primary key value to search for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:telemetry_event` - Override telemetry event name

  ## Returns

  - The record struct if found
  - `nil` if no record exists with the given primary key

  ## Examples

      # Get user by ID
      user = Users.get(1)
      # => %Users.Struct{id: 1, name: "John", email: "john@example.com"}

      # Returns nil if not found
      user = Users.get(999)
      # => nil

      # Override repository
      user = Users.get(1, repo: AnotherRepo)

      # With timeout option
      user = Users.get(1, timeout: 5000)

  ## Error Handling

      case Users.get(user_id) do
        nil ->
          {:error, :not_found}
        user ->
          {:ok, user}
      end

  See `Ecto.Repo.get/3` for more details on the underlying implementation.
  """
  @doc group: "Query API"
  @spec get(term(), keyword()) :: struct() | nil
  def get(id, opts \\ []) do
    read(:get, [id], opts)
  end

  @doc """
  Fetches a single record by its primary key, raising if not found.

  This function retrieves a single record from the database using the primary key value.
  Unlike `get/2`, this function raises an `Ecto.NoResultsError` if no record is found
  with the given primary key.

  ## Parameters

  - `id` - The primary key value to search for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:telemetry_event` - Override telemetry event name

  ## Returns

  - The record struct if found
  - Raises `Ecto.NoResultsError` if no record exists with the given primary key

  ## Examples

      # Get user by ID
      user = Users.get!(1)
      # => %Users.Struct{id: 1, name: "John", email: "john@example.com"}

      # Raises if not found
      user = Users.get!(999)
      # => ** (Ecto.NoResultsError) expected at least one result but got none

      # Override repository
      user = Users.get!(1, repo: AnotherRepo)

      # With timeout option
      user = Users.get!(1, timeout: 5000)

  ## Error Handling

      try do
        user = Users.get!(user_id)
        process_user(user)
      rescue
        Ecto.NoResultsError ->
          {:error, :not_found}
      end

  See `Ecto.Repo.get!/3` for more details on the underlying implementation.
  """
  @doc group: "Query API"
  @spec get!(term(), keyword()) :: struct()
  def get!(id, opts \\ []) do
    read(:get!, [id], opts)
  end

  @doc """
  Gets a single record by the given clauses.

  Delegates to `Ecto.Repo.get_by/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.get_by(email: "user@example.com")
      user = MyRelation.get_by([email: "user@example.com"], repo: AnotherRepo)

  See [`Ecto.Repo.get_by/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:get_by/3) for more details.
  """
  @doc group: "Query API"
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
  @doc group: "Query API"
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

  See [`Ecto.Repo.all/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:all/2) for more details.
  """
  @doc group: "Query API"
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
  Fetches all records from the relation.

  This function retrieves all records from the database table associated with the relation.
  It can also execute a composable relation query built with functions like `restrict/2` and `order/2`.

  ## Parameters

  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:telemetry_event` - Override telemetry event name

  ## Returns

  A list of record structs. Returns an empty list if no records are found.

  ## Examples

      # Get all users
      users = Users.all()
      # => [%Users.Struct{id: 1, name: "John"}, %Users.Struct{id: 2, name: "Jane"}]

      # Execute a composable query
      active_users = Users
                     |> Users.restrict(active: true)
                     |> Users.order(:name)
                     |> Users.all()

      # Override repository
      users = Users.all(repo: AnotherRepo)

      # With timeout option
      users = Users.all(timeout: 10000)

  ## Performance Considerations

  Be cautious when calling `all/1` on large tables without restrictions,
  as it will load all records into memory.

      # Better: use restrictions to limit results
      recent_users = Users
                     |> Users.restrict(inserted_at: {:>, days_ago(30)})
                     |> Users.all()

  See `Ecto.Repo.all/2` for more details on the underlying implementation.
  """
  @doc group: "Query API"
  @spec all(keyword()) :: [struct()]
  def all(opts \\ []) do
    read(:all, [], opts)
  end

  @doc """
  Fetches all records from a composable relation query.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to execute queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Returns

  A list of record structs matching the relation query.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true)
      users = Users.all(query)

      # Equivalent to:
      users = Users
              |> Users.restrict(active: true)
              |> Users.all()
  """
  @doc group: "Query API"
  @spec all(struct(), keyword()) :: [struct()]
  def all(%{__struct__: relation_module} = relation, opts) do
    read(:all, [], Keyword.merge(opts, relation: relation_module, queryable: relation))
  end

  @doc """
  Fetches a single result from the query.

  Delegates to `Ecto.Repo.one/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.one(query)
      user = MyRelation.one(query, repo: AnotherRepo)

  See [`Ecto.Repo.one/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) for more details.
  """
  @doc group: "Query API"
  def one(opts \\ []) do
    read(:one, [], opts)
  end

  @doc """
  Fetches a single result from a composable relation query.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to execute queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  A single record struct matching the relation query, or `nil` if no record is found.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true)
      user = Users.one(query)

      # Equivalent to:
      user = Users
             |> Users.restrict(active: true)
             |> Users.one()
  """
  @doc group: "Query API"
  @spec one(struct(), keyword()) :: struct() | nil
  def one(%{__struct__: relation_module} = relation, opts) do
    read(:one, [], Keyword.merge(opts, relation: relation_module, queryable: relation))
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
  @doc group: "Query API"
  def one!(opts \\ []) do
    read(:one!, [], opts)
  end

  @doc """
  Fetches a single result from a composable relation query, raises if not found or more than one.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to execute queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  A single record struct matching the relation query. Raises `Ecto.NoResultsError` if no record
  is found, or `Ecto.MultipleResultsError` if more than one record is found.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true)
      user = Users.one!(query)

      # Equivalent to:
      user = Users
             |> Users.restrict(active: true)
             |> Users.one!()
  """
  @doc group: "Query API"
  @spec one!(struct(), keyword()) :: struct()
  def one!(%{__struct__: relation_module} = relation, opts) do
    read(:one!, [], Keyword.merge(opts, relation: relation_module, queryable: relation))
  end

  @doc """
  Returns the count of records.

  Delegates to `Ecto.Repo.aggregate/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      count = MyRelation.count()
      count = MyRelation.count(repo: AnotherRepo)

  See [`Ecto.Repo.aggregate/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/3) for more details.
  """
  @doc group: "Query API"
  def count(opts \\ []) do
    read(:aggregate, [:count], opts)
  end

  @doc """
  Returns the count of records from a composable relation query.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to count records from queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  An integer representing the count of records matching the relation query.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true)
      count = Users.count(query)

      # Equivalent to:
      count = Users
              |> Users.restrict(active: true)
              |> Users.count()
  """
  @doc group: "Query API"
  @spec count(struct(), keyword()) :: non_neg_integer()
  def count(%{__struct__: relation_module} = relation, opts) do
    read(
      :aggregate,
      [:count],
      Keyword.merge(opts, relation: relation_module, queryable: relation)
    )
  end

  @doc """
  Returns the first record.

  Delegates to `Ecto.Repo.one/2` with `Ecto.Query.first/1`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.first()
      user = MyRelation.first(repo: AnotherRepo)

  See [`Ecto.Repo.one/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) and
  [Ecto.Query.first/1](https://hexdocs.pm/ecto/Ecto.Query.html#first/1) for more details.
  """
  @doc group: "Query API"
  def first(opts \\ []) do
    read(:one, [], Keyword.merge(opts, queryable: Ecto.Query.first(opts[:relation])))
  end

  @doc """
  Returns the first record from a composable relation query.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to get the first record from queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  The first record struct matching the relation query, or `nil` if no records are found.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true) |> Users.order(:name)
      user = Users.first(query)

      # Equivalent to:
      user = Users
             |> Users.restrict(active: true)
             |> Users.order(:name)
             |> Users.first()
  """
  @doc group: "Query API"
  @spec first(struct(), keyword()) :: struct() | nil
  def first(%{__struct__: relation_module} = relation, opts) do
    queryable = Ecto.Query.first(relation)
    read(:one, [], Keyword.merge(opts, relation: relation_module, queryable: queryable))
  end

  @doc """
  Returns the last record.

  Delegates to `Ecto.Repo.one/2` with `Ecto.Query.last/1`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.last()
      user = MyRelation.last(repo: AnotherRepo)

  See [`Ecto.Repo.one/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:one/2) and
  [Ecto.Query.last/1](https://hexdocs.pm/ecto/Ecto.Query.html#last/1) for more details.
  """
  @doc group: "Query API"
  def last(opts \\ []) do
    read(:one, [], Keyword.merge(opts, queryable: Ecto.Query.last(opts[:relation])))
  end

  @doc """
  Returns the last record from a composable relation query.

  This function head handles the case where a composable relation struct is passed
  as the first argument, allowing you to get the last record from queries built with `restrict/2`, `order/2`, etc.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  The last record struct matching the relation query, or `nil` if no records are found.

  ## Examples

      # Build and execute a composable query
      query = Users.restrict(active: true) |> Users.order(:name)
      user = Users.last(query)

      # Equivalent to:
      user = Users
             |> Users.restrict(active: true)
             |> Users.order(:name)
             |> Users.last()
  """
  @doc group: "Query API"
  @spec last(struct(), keyword()) :: struct() | nil
  def last(%{__struct__: relation_module} = relation, opts) do
    queryable = Ecto.Query.last(relation)
    read(:one, [], Keyword.merge(opts, relation: relation_module, queryable: queryable))
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
  @doc group: "Query API"
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

  See [`Ecto.Repo.stream/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:stream/2) for more details.
  """
  @doc group: "Query API"
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

  See [`Ecto.Repo.aggregate/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/3) and
  [`Ecto.Repo.aggregate/4`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4) for more details.
  """
  @doc group: "Query API"
  def aggregate(aggregate, opts) do
    read(:aggregate, [aggregate], opts)
  end

  @doc group: "Query API"
  def aggregate(aggregate, field, opts) do
    read(:aggregate, [aggregate, field], opts)
  end

  @doc """
  Returns the minimum value for the given field.

  This is a convenience function that delegates to `aggregate/3` with `:min`.

  ## Parameters

  - `field` - The field to calculate the minimum value for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Examples

      min_age = Users.min(:age)
      min_age = Users.min(:age, repo: AnotherRepo)

  See `aggregate/3` for more details.
  """
  @doc group: "Query API"
  def min(field, opts \\ []) do
    read(:aggregate, [:min, field], opts)
  end

  @doc """
  Returns the minimum value for the given field from a composable relation query.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `field` - The field to calculate the minimum value for
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Examples

      query = Users.restrict(active: true)
      min_age = Users.min(query, :age)
  """
  @doc group: "Query API"
  def min(%{__struct__: relation_module} = relation, field, opts) do
    read(
      :aggregate,
      [:min, field],
      Keyword.merge(opts, relation: relation_module, queryable: relation)
    )
  end

  @doc """
  Returns the maximum value for the given field.

  This is a convenience function that delegates to `aggregate/3` with `:max`.

  ## Parameters

  - `field` - The field to calculate the maximum value for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Examples

      max_age = Users.max(:age)
      max_age = Users.max(:age, repo: AnotherRepo)

  See `aggregate/3` for more details.
  """
  @doc group: "Query API"
  def max(field, opts \\ []) do
    read(:aggregate, [:max, field], opts)
  end

  @doc """
  Returns the maximum value for the given field from a composable relation query.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `field` - The field to calculate the maximum value for
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Examples

      query = Users.restrict(active: true)
      max_age = Users.max(query, :age)
  """
  @doc group: "Query API"
  def max(%{__struct__: relation_module} = relation, field, opts) do
    read(
      :aggregate,
      [:max, field],
      Keyword.merge(opts, relation: relation_module, queryable: relation)
    )
  end

  @doc """
  Returns the sum of values for the given field.

  This is a convenience function that delegates to `aggregate/3` with `:sum`.

  ## Parameters

  - `field` - The field to calculate the sum for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Examples

      total_age = Users.sum(:age)
      total_age = Users.sum(:age, repo: AnotherRepo)

  See `aggregate/3` for more details.
  """
  @doc group: "Query API"
  def sum(field, opts \\ []) do
    read(:aggregate, [:sum, field], opts)
  end

  @doc """
  Returns the sum of values for the given field from a composable relation query.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `field` - The field to calculate the sum for
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Examples

      query = Users.restrict(active: true)
      total_age = Users.sum(query, :age)
  """
  @doc group: "Query API"
  def sum(%{__struct__: relation_module} = relation, field, opts) do
    read(
      :aggregate,
      [:sum, field],
      Keyword.merge(opts, relation: relation_module, queryable: relation)
    )
  end

  @doc """
  Returns the average value for the given field.

  This is a convenience function that delegates to `aggregate/3` with `:avg`.

  ## Parameters

  - `field` - The field to calculate the average for
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Examples

      avg_age = Users.avg(:age)
      avg_age = Users.avg(:age, repo: AnotherRepo)

  See `aggregate/3` for more details.
  """
  @doc group: "Query API"
  def avg(field, opts \\ []) do
    read(:aggregate, [:avg, field], opts)
  end

  @doc """
  Returns the average value for the given field from a composable relation query.

  ## Parameters

  - `relation` - A composable relation struct built with query functions
  - `field` - The field to calculate the average for
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Examples

      query = Users.restrict(active: true)
      avg_age = Users.avg(query, :age)
  """
  @doc group: "Query API"
  def avg(%{__struct__: relation_module} = relation, field, opts) do
    read(
      :aggregate,
      [:avg, field],
      Keyword.merge(opts, relation: relation_module, queryable: relation)
    )
  end

  @doc """
  Deletes all entries matching the given query.

  Delegates to `Ecto.Repo.delete_all/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {count, _} = MyRelation.delete_all()
      {count, _} = MyRelation.delete_all(repo: AnotherRepo)

  See [`Ecto.Repo.delete_all/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:delete_all/2) for more details.
  """
  @doc group: "Query API"
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

  See [`Ecto.Repo.update_all/3`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update_all/3) for more details.
  """
  @doc group: "Query API"
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

  See [`Ecto.Repo.transaction/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2) for more details.
  """
  @doc group: "Query API"
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
  @doc group: "Query API"
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

  See [`Ecto.Repo.checkout/2`](https://hexdocs.pm/ecto/Ecto.Repo.html#c:checkout/2) for more details.
  """
  @doc group: "Query API"
  def checkout(fun, opts) do
    relation = opts[:relation]
    repo = relation.repo()
    repo_opts = Keyword.delete(opts, :relation)

    apply(repo, :checkout, [fun, repo_opts])
  end

  defp read(fun, args, opts) do
    {_relation, repo, queryable, repo_opts} = clean_opts(opts)

    apply(repo, fun, [queryable] ++ args ++ [repo_opts])
  end

  def operation(name, opts) when is_atom(name) do
    {relation, _repo, queryable, rest_opts} = clean_opts(opts)
    operation_opts = Keyword.get(rest_opts, name, rest_opts)

    relation.add_operation(queryable, name, operation_opts)
  end

  def operation(other, name, opts) when is_struct(other) and is_map_key(other, :queryable) do
    {relation, _repo, _queryable, rest_opts} = clean_opts(opts)
    operation_opts = Keyword.get(rest_opts, name, rest_opts)

    relation.add_operation(other, name, operation_opts)
  end

  def operation(other, name, opts) when is_struct(other) do
    {relation, _repo, queryable, rest_opts} = clean_opts(opts, other)
    operation_opts = Keyword.get(rest_opts, name, rest_opts)

    relation.add_operation(relation.new(queryable), name, operation_opts)
  end

  def operation(other, name, opts) when is_atom(other) do
    {relation, _repo, queryable, rest_opts} = clean_opts(opts, other)
    operation_opts = Keyword.get(rest_opts, name, rest_opts)

    relation.add_operation(relation.new(queryable), name, operation_opts)
  end

  def clean_opts(opts, queryable \\ nil) do
    relation = opts[:relation]
    repo = relation.repo()
    queryable = Keyword.get(opts, :queryable) || queryable || relation.new()
    rest_opts = Keyword.delete(opts, :relation) |> Keyword.delete(:queryable)

    {relation, repo, queryable, rest_opts}
  end
end
