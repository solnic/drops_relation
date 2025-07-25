defmodule Sample.Repos.Sqlite do
  use Ecto.Repo,
    otp_app: :sample,
    adapter: Ecto.Adapters.SQLite3
end

defmodule Sample.Repos.Postgres do
  use Ecto.Repo,
    otp_app: :sample,
    adapter: Ecto.Adapters.Postgres
end
