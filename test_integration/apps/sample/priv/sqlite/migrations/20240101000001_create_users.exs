defmodule Sample.Repos.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:name, :string)
      add(:age, :integer)
      add(:active, :boolean, default: true)
      add(:profile_data, :map)
      add(:tags, {:array, :string}, default: [])
      add(:score, :float)
      add(:birth_date, :date)
      add(:last_login_at, :naive_datetime)

      timestamps()
    end

    create(unique_index(:users, [:email]))
    create(index(:users, [:active]))
  end
end
