defmodule Drops.Relation.Repos.Sqlite.Migrations.CreateMetadataTestTable do
  use Ecto.Migration

  def change do
    create table(:metadata_test) do
      # Field with default value
      add(:status, :string, default: "active", null: false)

      # Nullable field
      add(:description, :text, null: true)

      # Non-nullable field without default
      add(:name, :string, null: false)

      # Field with numeric default
      add(:priority, :integer, default: 1, null: false)

      # Field with boolean default
      add(:is_enabled, :boolean, default: true, null: false)

      # Field with check constraint (SQLite syntax)
      add(:score, :integer, null: false)

      timestamps()
    end

    # Add check constraint for score field
    execute(
      """
      CREATE TABLE metadata_test_new AS 
      SELECT * FROM metadata_test;
      """,
      ""
    )

    execute(
      """
      DROP TABLE metadata_test;
      """,
      ""
    )

    execute(
      """
      CREATE TABLE metadata_test (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        status TEXT DEFAULT 'active' NOT NULL,
        description TEXT,
        name TEXT NOT NULL,
        priority INTEGER DEFAULT 1 NOT NULL,
        is_enabled INTEGER DEFAULT 1 NOT NULL,
        score INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      """,
      """
      DROP TABLE metadata_test;
      """
    )

    create(index(:metadata_test, [:status]))
    create(index(:metadata_test, [:name, :priority]))
  end
end
