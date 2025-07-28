defmodule Test.Repos.Postgres.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:name, :string)
      add(:email, :string)
      add(:age, :integer)
      add(:active, :boolean)
      add(:settings, :map, default: "{}", null: false)

      timestamps()
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:name]))
    create(index(:users, [:name, :age]))
  end
end
