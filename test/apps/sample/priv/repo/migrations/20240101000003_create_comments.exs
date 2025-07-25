defmodule Sample.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add(:body, :text, null: false)
      add(:approved, :boolean, default: false)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:post_id, references(:posts, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:comments, [:user_id]))
    create(index(:comments, [:post_id]))
    create(index(:comments, [:approved]))
  end
end
