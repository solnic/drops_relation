defmodule Drops.Relation.Plugins.Pagination do
  @moduledoc """
  Plugin that provides pagination functionality for relation modules.

  This plugin adds pagination functions that return `Drops.Relation.Loaded` structs
  containing both the paginated data and metadata for navigation.

  ## Functions Added

  - `page/1` - Load a specific page with default per_page
  - `page/2` - Load a specific page with custom per_page
  - `per_page/1` - Set per_page for subsequent pagination
  - `per_page/2` - Set per_page on an existing relation

  ## Usage

      defmodule MyApp.Users do
        use Drops.Relation, repo: MyApp.Repo

        schema("users", infer: true)
      end

      # Basic pagination
      page1 = Users.page(1)                    # First page with default per_page (20)
      page2 = Users.page(2, 10)                # Second page with 10 records per page

      # Set per_page first, then paginate
      small_pages = Users.per_page(5)
      page1_small = Users.page(small_pages, 1) # First page with 5 records

      # Chain with other operations
      active_page1 = Users
                     |> Users.restrict(active: true)
                     |> Users.order(:name)
                     |> Users.per_page(10)
                     |> Users.page(1)

  ## Working with Results

      loaded = Users.page(1)

      # Access data using Enumerable protocol
      users = Enum.to_list(loaded)
      first_user = Enum.at(loaded, 0)
      user_names = Enum.map(loaded, & &1.name)

      # Access pagination metadata
      pagination = loaded.meta.pagination

      pagination.page         # => 1
      pagination.per_page     # => 20
      pagination.total_count  # => 150
      pagination.total_pages  # => 8
      pagination.has_next     # => true
      pagination.has_prev     # => false

  ## Configuration

  The default per_page value can be configured:

      config :my_app, :drops,
        relation: [
          default_per_page: 25
        ]

  If not configured, the default per_page is 20.
  """

  alias Drops.Relation.Loaded
  alias Drops.Relation.Plugins.Reading

  use Drops.Relation.Plugin

  @default_per_page 20

  def on(:before_compile, _relation, _) do
    quote do
      alias unquote(__MODULE__)

      delegate_to(page(page_num), to: Pagination)
      delegate_to(page(page_num, per_page), to: Pagination)
      delegate_to(page(other, page_num), to: Pagination)
      delegate_to(per_page(per_page), to: Pagination)
      delegate_to(per_page(other, per_page), to: Pagination)

      defquery paginate(offset, per_page) do
        from(q in relation(), offset: ^offset, limit: ^per_page)
      end
    end
  end

  @doc """
  Loads a specific page with the default per_page setting.

  ## Parameters

  - `page_num` - The page number to load (1-based)
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  Returns a `Drops.Relation.Loaded` struct with the paginated data and metadata.

  ## Examples

      # Load first page with default per_page
      page1 = Users.page(1)

      # Load third page
      page3 = Users.page(3)
  """
  @spec page(pos_integer(), keyword()) :: Loaded.t()
  def page(page_num, opts) when is_integer(page_num) and page_num > 0 do
    page(page_num, get_default_per_page(opts[:relation]), opts)
  end

  @doc """
  Loads a specific page with a custom per_page setting.

  ## Parameters

  - `page_num` - The page number to load (1-based)
  - `per_page` - Number of records per page
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  Returns a `Drops.Relation.Loaded` struct with the paginated data and metadata.

  ## Examples

      # Load first page with 10 records per page
      page1 = Users.page(1, 10)

      # Load second page with 5 records per page
      page2 = Users.page(2, 5)
  """
  @spec page(pos_integer(), pos_integer(), keyword()) :: Loaded.t()
  def page(page_num, per_page, opts)
      when is_integer(page_num) and page_num > 0 and is_integer(per_page) and per_page > 0 do
    {relation_module, _repo, relation, _rest_opts} = Reading.clean_opts(opts)

    meta = meta(relation, page_num, per_page, opts)

    relation_module.load(paginate(relation, meta), %{pagination: meta})
  end

  @spec page(struct(), pos_integer(), keyword()) :: Loaded.t()
  def page(relation, page_num, opts) when is_integer(page_num) and page_num > 0 do
    {relation_module, _repo, _queryable, _rest_opts} = Reading.clean_opts(opts)

    meta = meta(relation, page_num, opts)

    relation_module.load(paginate(relation, meta), %{pagination: meta})
  end

  @doc """
  Sets the per_page value for subsequent pagination operations.

  ## Parameters

  - `per_page` - Number of records per page
  - `opts` - Additional options (automatically provided by delegate_to)

  ## Returns

  Returns a relation struct with per_page metadata.

  ## Examples

      # Set per_page for later use
      relation = Users.per_page(10)
      page1 = Users.page(relation, 1)
  """
  @spec per_page(pos_integer(), keyword()) :: struct()
  def per_page(per_page, opts) when is_integer(per_page) and per_page > 0 do
    Reading.operation(:pagination, Keyword.put(opts, :pagination, per_page: per_page))
  end

  @spec per_page(Ecto.Queryable.t(), pos_integer(), keyword()) :: struct()
  def per_page(other, per_page, opts) when is_integer(per_page) and per_page > 0 do
    Reading.operation(other, :pagination, Keyword.put(opts, :pagination, per_page: per_page))
  end

  defp paginate(%{__struct__: relation} = queryable, meta) do
    relation.paginate(queryable, meta.offset, meta.per_page)
  end

  defp meta(relation, page_num, opts) when is_list(opts) do
    meta(relation, page_num, get_per_page_from_relation(relation), opts)
  end

  defp meta(relation, page_num, per_page, opts) do
    offset = (page_num - 1) * per_page
    total_count = Reading.count(relation, opts)
    total_pages = if total_count == 0, do: 0, else: ceil(total_count / per_page)

    %{
      offset: offset,
      per_page: per_page,
      page: page_num,
      total_count: total_count,
      total_pages: total_pages,
      has_next: page_num < total_pages,
      has_prev: page_num > 1
    }
  end

  defp get_default_per_page(relation) do
    case Drops.Relation.Plugin.config([relation: relation], :default_per_page) do
      nil -> @default_per_page
      value when is_integer(value) and value > 0 -> value
      _ -> @default_per_page
    end
  end

  defp get_per_page_from_relation(%{opts: opts} = relation) do
    case Keyword.get(opts, :pagination) do
      pagination_opts when is_list(pagination_opts) ->
        Keyword.get(pagination_opts, :per_page)

      _ ->
        get_default_per_page(relation)
    end
  end

  defp get_per_page_from_relation(_), do: nil
end
