defmodule Drops.Relation.Plugins.Writing do
  @moduledoc """
  Plugin that provides writing operations for relation modules.

  This plugin adds Ecto.Repo-like functions for creating, updating, and deleting data:
  - Insert operations (`insert/2`, `insert!/2`, `insert_all/2`)
  - Update operations (`update/2`, `update!/2`)
  - Delete operations (`delete/2`, `delete!/2`)
  - Changeset operations (`changeset/2`)
  - Reload operations (`reload/2`, `reload!/2`)

  All functions delegate to the corresponding Ecto.Repo functions with automatic
  repository and relation configuration.

  ## Examples

      iex> {:ok, user} = MyApp.Users.insert(%{name: "Alice", email: "alice.new@example.com", age: 28, active: true})
      iex> user.name
      "Alice"
      iex> user.email
      "alice.new@example.com"

      iex> # Insert with changeset
      iex> changeset = MyApp.Users.changeset(%{name: "Charlie", email: "charlie.new@example.com", age: 32, active: true})
      iex> {:ok, user} = MyApp.Users.insert(changeset)
      iex> user.name
      "Charlie"

      iex> # Update existing user
      iex> existing_user = MyApp.Users.get(1)
      iex> {:ok, updated_user} = MyApp.Users.update(existing_user, %{name: "John Updated"})
      iex> updated_user.name
      "John Updated"

      iex> # Delete user
      iex> user_to_delete = MyApp.Users.get(2)
      iex> {:ok, deleted_user} = MyApp.Users.delete(user_to_delete)
      iex> deleted_user.name
      "Jane Smith"
  """

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
  Inserts a new record into the database.

  This function accepts a struct, changeset, or plain map and inserts it into the database.
  When given a plain map, it automatically creates a struct using the relation's schema.
  Returns a tuple with the operation result.

  ## Parameters

  - `struct_or_changeset` - The data to insert (struct, changeset, or plain map)
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:returning` - Fields to return from the inserted record
  - `:on_conflict` - How to handle conflicts (e.g., `:raise`, `:nothing`, `:replace_all`)

  ## Returns

  - `{:ok, struct}` - Successfully inserted record
  - `{:error, changeset}` - Validation or database errors

  ## Examples

      iex> # Insert with plain map
      iex> {:ok, user} = MyApp.Users.insert(%{name: "David", email: "david.test@example.com", age: 29, active: true})
      iex> user.name
      "David"
      iex> user.email
      "david.test@example.com"

      iex> # Insert with changeset
      iex> changeset = MyApp.Users.changeset(%{name: "Emma", email: "emma.test@example.com", age: 26, active: true})
      iex> {:ok, user} = MyApp.Users.insert(changeset)
      iex> user.name
      "Emma"

  ## Validation

  If the data fails validation, returns `{:error, changeset}` with detailed error information:

      {:error, changeset} = Users.insert(%{email: "invalid-email"})
      changeset.errors
      # => [email: {"has invalid format", [validation: :format]}]

  See `Ecto.Repo.insert/2` for more details on the underlying implementation.
  """
  @spec insert(struct() | Ecto.Changeset.t() | map(), keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def insert(struct_or_changeset, opts \\ []) do
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

  ## Parameters

  - `struct_or_changeset` - A struct, changeset, or plain map to insert
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:returning` - Fields to return from the inserted record
  - `:on_conflict` - How to handle conflicts (e.g., `:raise`, `:nothing`, `:replace_all`)

  ## Returns

  The inserted record struct, raises on error.

  ## Examples

      iex> user = MyApp.Users.insert!(%{name: "Alice", email: "alice.unique@example.com", age: 28, active: true})
      iex> user.name
      "Alice"
      iex> user.email
      "alice.unique@example.com"

      iex> # Insert with changeset
      iex> changeset = MyApp.Users.changeset(%{name: "Bob", email: "bob.unique@example.com", age: 35, active: false})
      iex> user = MyApp.Users.insert!(changeset)
      iex> user.name
      "Bob"

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

  ## Parameters

  - `struct` - The struct to update
  - `attributes` - Map of attributes to update
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration
  - `:force_changes` - Force changes even if values haven't changed

  ## Returns

  - `{:ok, struct}` - Successfully updated record
  - `{:error, changeset}` - Validation or database errors

  ## Examples

      iex> user = MyApp.Users.get(1)
      iex> {:ok, updated_user} = MyApp.Users.update(user, %{name: "John Updated"})
      iex> updated_user.name
      "John Updated"

      iex> # Update with multiple attributes
      iex> user = MyApp.Users.get(2)
      iex> {:ok, updated_user} = MyApp.Users.update(user, %{name: "Jane Updated", age: 26})
      iex> updated_user.name
      "Jane Updated"
      iex> updated_user.age
      26

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

  ## Parameters

  - `struct` - The struct to delete
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:repo` - Override the default repository
  - `:timeout` - Query timeout in milliseconds
  - `:log` - Override logging configuration

  ## Returns

  - `{:ok, struct}` - Successfully deleted record
  - `{:error, changeset}` - Database errors

  ## Examples

      iex> user = MyApp.Users.get(3)
      iex> {:ok, deleted_user} = MyApp.Users.delete(user)
      iex> deleted_user.name
      "Bob Wilson"
      iex> deleted_user.id
      3

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

  ## Parameters

  - `params` - Map of parameters to cast into a changeset
  - `opts` - Additional options (optional, defaults to `[]`)

  ## Options

  - `:empty_values` - A list of values to be considered as empty when casting
  - `:force_changes` - A boolean indicating whether to include values that don't alter the current data

  ## Returns

  An `Ecto.Changeset` struct with the cast parameters.

  ## Examples

      iex> changeset = MyApp.Users.changeset(%{name: "Frank", email: "frank.changeset@example.com", age: 31, active: true})
      iex> changeset.valid?
      true
      iex> changeset.changes.name
      "Frank"
      iex> changeset.changes.email
      "frank.changeset@example.com"

      iex> # With existing struct
      iex> user = MyApp.Users.get(1)
      iex> changeset = MyApp.Users.changeset(user, %{name: "John Updated Again"})
      iex> changeset.changes.name
      "John Updated Again"

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
