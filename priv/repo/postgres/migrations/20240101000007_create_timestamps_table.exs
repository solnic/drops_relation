defmodule Ecto.Relation.Repos.Postgres.Migrations.CreateTimestampsTable do
  use Ecto.Migration

  def change do
    create table(:timestamps) do
      add :name, :string

      timestamps()
    end
  end
end
