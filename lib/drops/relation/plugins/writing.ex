defmodule Drops.Relation.Plugins.Writing do
  use Drops.Relation.Plugin

  def on(:before_compile, _relation, _) do
    quote do
      alias unquote(__MODULE__)

      delegate_to(insert(struct_or_changeset), to: Writing)
      delegate_to(insert!(struct_or_changeset), to: Writing)
      delegate_to(update(struct, attributes), to: Writing)
      delegate_to(update(changeset), to: Writing)
      delegate_to(update!(struct, attributes), to: Writing)
      delegate_to(update!(changeset), to: Writing)
      delegate_to(delete(struct), to: Writing)
      delegate_to(delete!(struct), to: Writing)
      delegate_to(changeset(params), to: Writing)
      delegate_to(changeset(struct, params), to: Writing)
      delegate_to(reload(struct), to: Writing)
      delegate_to(reload!(struct), to: Writing)
      delegate_to(insert_all(entries), to: Writing)

      def struct(attributes \\ %{}) do
        struct(__schema_module__(), attributes)
      end
    end
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
  Updates a struct with the given attributes.

  Creates a changeset from the struct and attributes, then delegates to `Ecto.Repo.update/2`.
  The `:repo` and `:relation` options are automatically set based on the repository and relation
  module configured in the `use` macro, but can be overridden.

  ## Examples

      {:ok, user} = MyRelation.update(user_struct, %{name: "Jane"})
      {:ok, user} = MyRelation.update(user_struct, %{name: "Jane"}, repo: AnotherRepo)

  See [Ecto.Repo.update/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update/2) for more details.
  """
  def update(struct, attributes, opts) when is_struct(struct) and is_map(attributes) do
    changeset = changeset(struct, attributes, opts)
    opts[:relation].opts(:repo).update(changeset, Keyword.delete(opts, :relation))
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
  def update(%Ecto.Changeset{} = changeset, opts) do
    opts[:relation].opts(:repo).update(changeset, Keyword.delete(opts, :relation))
  end

  @doc """
  Updates a struct with the given attributes, raises on error.

  Creates a changeset from the struct and attributes, then delegates to `Ecto.Repo.update!/2`.
  The `:repo` and `:relation` options are automatically set based on the repository and relation
  module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.update!(user_struct, %{name: "Jane"})
      user = MyRelation.update!(user_struct, %{name: "Jane"}, repo: AnotherRepo)

  See [Ecto.Repo.update!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:update!/2) for more details.
  """
  def update!(struct, attributes, opts) when is_struct(struct) and is_map(attributes) do
    changeset = changeset(struct, attributes, opts)
    opts[:relation].opts(:repo).update!(changeset, Keyword.delete(opts, :relation))
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
  def update!(%Ecto.Changeset{} = changeset, opts) do
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
  Creates a changeset from a map and opts.

  Uses the relation schema to automatically cast fields based on their types.
  The changeset can be used for validation and database operations.

  ## Examples

      changeset = MyRelation.changeset(%{name: "John", email: "john@example.com"})
      {:ok, user} = MyRelation.insert(changeset)

      # With existing struct
      changeset = MyRelation.changeset(user, %{name: "Jane"})
      {:ok, updated_user} = MyRelation.update(changeset)

  ## Options

  * `:empty_values` - a list of values to be considered as empty when casting
  * `:force_changes` - a boolean indicating whether to include values that don't alter the current data

  See [Ecto.Changeset.cast/4](https://hexdocs.pm/ecto/Ecto.Changeset.html#cast/4) for more details.
  """
  def changeset(params, opts) when is_map(params) and is_list(opts) do
    relation = opts[:relation]
    schema = relation.schema()
    schema_module = relation.__schema_module__()

    # Create a new struct
    struct = struct(schema_module, %{})

    # Get field names and types from schema
    field_names = Enum.map(schema.fields, & &1.name)

    # Cast the parameters
    Ecto.Changeset.cast(struct, params, field_names, Keyword.delete(opts, :relation))
  end

  def changeset(struct, params, opts)
      when is_struct(struct) and is_map(params) and is_list(opts) do
    relation = opts[:relation]
    schema = relation.schema()

    # Get field names from schema
    field_names = Enum.map(schema.fields, & &1.name)

    # Cast the parameters onto the existing struct
    Ecto.Changeset.cast(struct, params, field_names, Keyword.delete(opts, :relation))
  end

  @doc """
  Reloads a struct from the database.

  Delegates to `Ecto.Repo.reload/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.reload(user)
      user = MyRelation.reload(user, repo: AnotherRepo)

  See [Ecto.Repo.reload/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:reload/2) for more details.
  """
  def reload(struct, opts) do
    opts[:relation].opts(:repo).reload(struct, Keyword.delete(opts, :relation))
  end

  @doc """
  Reloads a struct from the database, raises on error.

  Delegates to `Ecto.Repo.reload!/2`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      user = MyRelation.reload!(user)
      user = MyRelation.reload!(user, repo: AnotherRepo)

  See [Ecto.Repo.reload!/2](https://hexdocs.pm/ecto/Ecto.Repo.html#c:reload!/2) for more details.
  """
  def reload!(struct, opts) do
    opts[:relation].opts(:repo).reload!(struct, Keyword.delete(opts, :relation))
  end

  @doc """
  Inserts all entries into the repository.

  Delegates to `Ecto.Repo.insert_all/3`. The `:repo` and `:relation` options are automatically set
  based on the repository and relation module configured in the `use` macro, but can be overridden.

  ## Examples

      {count, structs} = MyRelation.insert_all([%{name: "John"}, %{name: "Jane"}])
      {count, structs} = MyRelation.insert_all(entries, repo: AnotherRepo)

  See [Ecto.Repo.insert_all/3](https://hexdocs.pm/ecto/Ecto.Repo.html#c:insert_all/3) for more details.
  """
  def insert_all(entries, opts) do
    relation = opts[:relation]
    schema_module = relation.__schema_module__()
    repo = relation.opts(:repo)
    repo_opts = Keyword.delete(opts, :relation)

    apply(repo, :insert_all, [schema_module, entries, repo_opts])
  end
end
