defmodule Test.Repos.Sqlite.Migrations.CreatePostsTable do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add(:title, :string, null: false)
      add(:body, :text)
      add(:published, :boolean, default: false)
      add(:view_count, :integer, default: 0)
      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index(:posts, [:user_id]))
    create(index(:posts, [:published]))
    create(index(:posts, [:title]))
  end
end
