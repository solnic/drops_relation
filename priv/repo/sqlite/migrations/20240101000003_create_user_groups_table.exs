defmodule Test.Repos.Sqlite.Migrations.CreateUserGroupsTable do
  use Ecto.Migration

  def change do
    create table(:user_groups) do
      add(:user_id, references(:users, on_delete: :delete_all))
      add(:group_id, references(:groups, on_delete: :delete_all))

      timestamps()
    end

    create(unique_index(:user_groups, [:user_id, :group_id]))
  end
end
