defmodule Drops.Relation.Query do
  alias Drops.Relation.Query.SchemaCompiler

  alias __MODULE__

  @doc false
  def generate_functions(opts, schema) do
    repo = opts[:repo]

    # Basic Ecto.Repo functions that delegate to module-level functions
    basic_functions = [
      generate_delegating_get_function(repo),
      generate_delegating_get_bang_function(repo),
      generate_delegating_get_by_function(repo),
      generate_delegating_get_by_bang_function(repo),
      generate_delegating_all_function(repo),
      generate_delegating_one_function(repo),
      generate_delegating_one_bang_function(repo),
      generate_delegating_insert_function(repo),
      generate_delegating_insert_bang_function(repo),
      generate_delegating_update_function(repo),
      generate_delegating_update_bang_function(repo),
      generate_delegating_delete_function(repo),
      generate_delegating_delete_bang_function(repo),
      generate_delegating_count_function(repo),
      generate_delegating_first_function(repo),
      generate_delegating_last_function(repo)
    ]

    # Index-based finder functions
    index_functions = SchemaCompiler.visit(schema, %{repo: repo})

    basic_functions ++ index_functions
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
  def get(queryable, id, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.get(actual_queryable, id, cleaned_opts)
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
  def get!(queryable, id, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.get!(actual_queryable, id, cleaned_opts)
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
  def get_by(queryable, clauses, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.get_by(actual_queryable, clauses, cleaned_opts)
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
  def get_by!(queryable, clauses, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.get_by!(actual_queryable, clauses, cleaned_opts)
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
  def all(queryable, opts \\ []) do
    opts[:repo].all(queryable, Keyword.delete(opts, :repo))
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
  def one(queryable, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.one(actual_queryable, cleaned_opts)
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
  def one!(queryable, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.one!(actual_queryable, cleaned_opts)
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
  def insert(struct_or_changeset, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_struct =
      case struct_or_changeset do
        %{__struct__: _} ->
          # Already a struct or changeset
          struct_or_changeset

        %{} = plain_map when relation_module != nil ->
          # Plain map - convert to struct first using relation module
          struct_module = relation_module.__schema_module__()
          struct(struct_module, plain_map)

        %{} = plain_map ->
          # Plain map without relation module - pass as is
          plain_map
      end

    repo.insert(actual_struct, cleaned_opts)
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
  def insert!(struct_or_changeset, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_struct =
      case struct_or_changeset do
        %{__struct__: _} ->
          # Already a struct or changeset
          struct_or_changeset

        %{} = plain_map when relation_module != nil ->
          # Plain map - convert to struct first using relation module
          struct_module = relation_module.__schema_module__()
          struct(struct_module, plain_map)

        %{} = plain_map ->
          # Plain map without relation module - pass as is
          plain_map
      end

    repo.insert!(actual_struct, cleaned_opts)
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
  def update(changeset, opts \\ []) do
    repo = opts[:repo]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)
    repo.update(changeset, cleaned_opts)
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
  def update!(changeset, opts \\ []) do
    repo = opts[:repo]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)
    repo.update!(changeset, cleaned_opts)
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
  def delete(struct, opts \\ []) do
    repo = opts[:repo]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)
    repo.delete(struct, cleaned_opts)
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
  def delete!(struct, opts \\ []) do
    repo = opts[:repo]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)
    repo.delete!(struct, cleaned_opts)
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
  def count(queryable, aggregate \\ :count, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.aggregate(actual_queryable, aggregate, cleaned_opts)
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
  def first(queryable, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.one(Ecto.Query.first(actual_queryable), cleaned_opts)
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
  def last(queryable, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        queryable
      end

    repo.one(Ecto.Query.last(actual_queryable), cleaned_opts)
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
  def get_by_field(field, value, opts \\ []) do
    repo = opts[:repo]
    relation_module = opts[:relation]
    cleaned_opts = opts |> Keyword.delete(:repo) |> Keyword.delete(:relation)

    actual_queryable =
      if relation_module do
        relation_module.__schema_module__()
      else
        # This shouldn't happen in normal usage since get_by_field is typically used with relations
        raise ArgumentError,
              "get_by_field requires :relation option when not called from a relation module"
      end

    repo.get_by(actual_queryable, [{field, value}], cleaned_opts)
  end

  # Delegating function generators - these generate functions that delegate to module-level functions
  defp generate_delegating_get_function(repo) do
    quote do
      def get(id, opts \\ []) do
        Query.get(
          __MODULE__.__schema_module__(),
          id,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_get_bang_function(repo) do
    quote do
      def get!(id, opts \\ []) do
        Query.get!(
          __MODULE__.__schema_module__(),
          id,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_get_by_function(repo) do
    quote do
      def get_by(clauses, opts \\ []) do
        Query.get_by(
          __MODULE__.__schema_module__(),
          clauses,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_get_by_bang_function(repo) do
    quote do
      def get_by!(clauses, opts \\ []) do
        Query.get_by!(
          __MODULE__.__schema_module__(),
          clauses,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_all_function(repo) do
    quote do
      def all(queryable \\ nil, opts \\ []) do
        actual_queryable = queryable || __MODULE__.__schema_module__()

        Query.all(
          actual_queryable,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_one_function(repo) do
    quote do
      def one(queryable, opts \\ []) do
        Query.one(
          queryable,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_one_bang_function(repo) do
    quote do
      def one!(queryable, opts \\ []) do
        Query.one!(
          queryable,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_insert_function(repo) do
    quote do
      def insert(struct_or_changeset_or_map, opts \\ []) do
        Query.insert(
          struct_or_changeset_or_map,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_insert_bang_function(repo) do
    quote do
      def insert!(struct_or_changeset_or_map, opts \\ []) do
        Query.insert!(
          struct_or_changeset_or_map,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_update_function(repo) do
    quote do
      def update(changeset, opts \\ []) do
        Query.update(
          changeset,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_update_bang_function(repo) do
    quote do
      def update!(changeset, opts \\ []) do
        Query.update!(
          changeset,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_delete_function(repo) do
    quote do
      def delete(struct, opts \\ []) do
        Query.delete(
          struct,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_delete_bang_function(repo) do
    quote do
      def delete!(struct, opts \\ []) do
        Query.delete!(
          struct,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_count_function(repo) do
    quote do
      def count(queryable \\ nil, opts \\ []) do
        actual_queryable = queryable || __MODULE__.__schema_module__()

        Query.count(
          actual_queryable,
          :count,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_first_function(repo) do
    quote do
      def first(queryable \\ nil, opts \\ []) do
        actual_queryable = queryable || __MODULE__.__schema_module__()

        Query.first(
          actual_queryable,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end

  defp generate_delegating_last_function(repo) do
    quote do
      def last(queryable \\ nil, opts \\ []) do
        actual_queryable = queryable || __MODULE__.__schema_module__()

        Query.last(
          actual_queryable,
          opts |> Keyword.put(:repo, unquote(repo)) |> Keyword.put(:relation, __MODULE__)
        )
      end
    end
  end
end
