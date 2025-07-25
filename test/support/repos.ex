defmodule Test.Repos do
  @moduledoc false

  @adapters [:sqlite, :postgres]

  def start(repo_or_adapter, mode \\ :auto)

  def start(:all, mode), do: Enum.each(@adapters, &start(&1, mode))
  def start(:sqlite, mode), do: start(Test.Repos.Sqlite, mode)
  def start(:postgres, mode), do: start(Test.Repos.Postgres, mode)

  def start(repo, mode) do
    {:ok, pid} = repo.start_link()
    env = Application.get_env(:drops_relation, :env, :test)
    Ecto.Adapters.SQL.Sandbox.mode(repo, mode || mode(env))
    :persistent_term.put({:repos, repo}, pid)
  end

  def stop(repo) do
    pid = :persistent_term.get({:repos, repo, :owner})
    Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
  end

  defp mode(:dev), do: :auto
  defp mode(:test), do: :manual

  def start_owner!(repo, opts \\ [])

  def start_owner!(:sqlite, opts), do: start_owner!(Test.Repos.Sqlite, opts)
  def start_owner!(:postgres, opts), do: start_owner!(Test.Repos.Postgres, opts)

  def start_owner!(repo, opts) do
    case ensure_started(repo) do
      {:ok, _pid} ->
        try do
          pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, opts)

          :persistent_term.put({:repos, repo, :owner}, pid)
        rescue
          error ->
            if opts[:retry] <= 3 do
              start_owner!(repo, Keyword.put(opts, :retry, opts[:retry] || 0 + 1))
            else
              reraise error, __STACKTRACE__
            end
        end

      {:error, error} ->
        raise "Failed to start repo #{repo}: #{inspect(error)}"
    end
  end

  def stop_owner(:sqlite), do: stop_owner(Test.Repos.Sqlite)
  def stop_owner(:postgres), do: stop_owner(Test.Repos.Postgres)

  def stop_owner(repo) do
    Ecto.Adapters.SQL.Sandbox.stop_owner(:persistent_term.get({:repos, repo, :owner}))
  end

  def with_owner(repo, fun) do
    try do
      start_owner!(repo, shared: false)
      fun.(repo)
    rescue
      error ->
        reraise error, __STACKTRACE__
    after
      if repo_pid(repo) do
        stop_owner(repo)
      end
    end
  end

  def each_repo(fun) do
    Enum.each(Application.get_env(:drops_relation, :ecto_repos), &fun.(&1))
  end

  defp ensure_started(repo) do
    case Process.whereis(repo) do
      nil ->
        try do
          :ok = Test.Repos.start(repo)

          {:ok, repo_pid(repo)}
        rescue
          error ->
            {:error, error}
        end

      pid ->
        {:ok, pid}
    end
  end

  defp repo_pid(repo) do
    :persistent_term.get({:repos, repo})
  end
end

defmodule Test.Repos.Sqlite do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :drops_relation,
    adapter: Ecto.Adapters.SQLite3
end

defmodule Test.Repos.Postgres do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :drops_relation,
    adapter: Ecto.Adapters.Postgres
end
