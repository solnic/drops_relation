defmodule Ecto.Relation.Repos.Sqlite.Migrations.CreateUuidTables do
  use Ecto.Migration

  def change do
    # Create uuid_organizations table first (referenced by users)
    create table(:uuid_organizations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string

      timestamps()
    end

    # Create uuid_users table
    create table(:uuid_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :email, :string
      add :organization_id, references(:uuid_organizations, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    # Create uuid_posts table
    create table(:uuid_posts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string
      add :content, :string
      add :user_id, references(:uuid_users, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    # Add indexes for foreign keys
    create index(:uuid_users, [:organization_id])
    create index(:uuid_posts, [:user_id])
  end
end
