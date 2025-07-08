defmodule Ecto.Relation.Repos.Sqlite.Migrations.CreateTimestampsTable do
  use Ecto.Migration

  def change do
    create table(:timestamps) do
      add :name, :string

      timestamps()
    end
  end
end
