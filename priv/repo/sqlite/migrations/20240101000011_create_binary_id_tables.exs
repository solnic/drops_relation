defmodule Test.Repos.Sqlite.Migrations.CreateBinaryIdTables do
  use Ecto.Migration

  def change do
    # Create binary_id_organizations table first (referenced by users)
    create table(:binary_id_organizations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string)

      timestamps()
    end

    # Create binary_id_users table
    create table(:binary_id_users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string)
      add(:email, :string)

      add(
        :organization_id,
        references(:binary_id_organizations, type: :binary_id, on_delete: :delete_all)
      )

      timestamps()
    end

    # Create binary_id_posts table
    create table(:binary_id_posts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string)
      add(:content, :string)
      add(:user_id, references(:binary_id_users, type: :binary_id, on_delete: :delete_all))

      timestamps()
    end

    # Add indices for foreign keys
    create(index(:binary_id_users, [:organization_id]))
    create(index(:binary_id_posts, [:user_id]))
  end
end
