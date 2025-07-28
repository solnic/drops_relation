defmodule MyApp do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link([], opts)
  end
end

defmodule MyApp.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end
