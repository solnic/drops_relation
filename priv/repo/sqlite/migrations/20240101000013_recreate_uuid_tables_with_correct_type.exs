defmodule Drops.Relation.Repos.Sqlite.Migrations.RecreateUuidTablesWithCorrectType do
  use Ecto.Migration

  def up do
    # Drop existing tables
    drop_if_exists table(:uuid_posts)
    drop_if_exists table(:uuid_users)
    drop_if_exists table(:uuid_organizations)

    # Create tables with explicit UUID type (not :uuid which gets converted to TEXT)
    execute """
    CREATE TABLE uuid_organizations (
      id UUID PRIMARY KEY,
      name TEXT,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """

    execute """
    CREATE TABLE uuid_users (
      id UUID PRIMARY KEY,
      name TEXT,
      email TEXT,
      organization_id UUID,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (organization_id) REFERENCES uuid_organizations(id) ON DELETE CASCADE
    )
    """

    execute """
    CREATE TABLE uuid_posts (
      id UUID PRIMARY KEY,
      title TEXT,
      content TEXT,
      user_id UUID,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES uuid_users(id) ON DELETE CASCADE
    )
    """

    # Add indices for foreign keys
    create index(:uuid_users, [:organization_id])
    create index(:uuid_posts, [:user_id])
  end

  def down do
    drop_if_exists table(:uuid_posts)
    drop_if_exists table(:uuid_users)
    drop_if_exists table(:uuid_organizations)
  end
end
