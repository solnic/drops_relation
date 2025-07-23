defmodule Test.Repos.Sqlite.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:name, :string)
      add(:email, :string)
      add(:age, :integer)
      add(:active, :boolean, default: false)

      timestamps()
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:name]))
    create(index(:users, [:name, :age]))
  end
end
