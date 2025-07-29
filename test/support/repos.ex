defmodule Test.Repos do
  @moduledoc false

  @adapters [:sqlite, :postgres]

  def start_all(mode) do
    Enum.each(@adapters, &start(&1, mode))
    start(MyApp.Repo, mode)
  end

  def start(adapter, mode \\ :auto)

  def start(:sqlite, mode), do: start(Test.Repos.Sqlite, mode)
  def start(:postgres, mode), do: start(Test.Repos.Postgres, mode)

  def start(repo, mode) do
    case Process.whereis(repo) do
      nil ->
        {:ok, _pid} = repo.start_link()

        :ok = Ecto.Adapters.SQL.Sandbox.mode(repo, mode)

      _pid ->
        :ok
    end
  end

  def stop_owner(:sqlite), do: stop_owner(Test.Repos.Sqlite)
  def stop_owner(:postgres), do: stop_owner(Test.Repos.Postgres)

  def stop_owner(repo) do
    case owner_pid(repo) do
      nil ->
        :ok

      pid ->
        try do
          Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
        rescue
          _ -> :ok
        end

        :persistent_term.erase({:repos, repo, :owner})
        :ok
    end
  end

  def start_owner!(repo, opts \\ [])

  def start_owner!(:sqlite, opts), do: start_owner!(Test.Repos.Sqlite, opts)
  def start_owner!(:postgres, opts), do: start_owner!(Test.Repos.Postgres, opts)

  def start_owner!(repo, opts) do
    retry_count = Keyword.get(opts, :retry, 0)
    max_retries = Keyword.get(opts, :max_retries, 3)

    try do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, opts)
      :persistent_term.put({:repos, repo, :owner}, pid)
      :ok
    rescue
      error ->
        case error do
          %MatchError{term: {:error, {{:badmatch, :already_shared}, _}}} ->
            :ok

          _ ->
            if retry_count < max_retries do
              cleanup_owner_state(repo)
              Process.sleep(50 * (retry_count + 1))

              retry_opts = Keyword.put(opts, :retry, retry_count + 1)
              start_owner!(repo, retry_opts)
            else
              reraise error, __STACKTRACE__
            end
        end
    end
  end

  def with_owner(repo, fun) do
    try do
      start_owner!(repo, shared: false)
      fun.(repo)
    rescue
      error ->
        reraise error, __STACKTRACE__
    after
      stop_owner(repo)
    end
  end

  def each_repo(fun) do
    Enum.each(Application.get_env(:drops_relation, :ecto_repos), &fun.(&1))
  end

  defp owner_pid(repo) do
    :persistent_term.get({:repos, repo, :owner}, nil)
  end

  defp cleanup_owner_state(repo) do
    try do
      case owner_pid(repo) do
        nil ->
          :ok

        _pid ->
          :persistent_term.erase({:repos, repo, :owner})
          :ok
      end
    rescue
      _ -> :ok
    end
  end
end

defmodule Test.Repos.Sqlite do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :drops_relation,
    pool: Ecto.Adapters.SQL.Sandbox,
    adapter: Ecto.Adapters.SQLite3
end

defmodule Test.Repos.Postgres do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :drops_relation,
    pool: Ecto.Adapters.SQL.Sandbox,
    adapter: Ecto.Adapters.Postgres
end

defmodule MyApp.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :drops_relation,
    pool: Ecto.Adapters.SQL.Sandbox,
    adapter: Ecto.Adapters.Postgres
end
