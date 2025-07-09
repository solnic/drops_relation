defmodule Drops.Relation.Repos.Postgres.Migrations.CreateMetadataTestTable do
  use Ecto.Migration

  def change do
    create table(:metadata_test) do
      # Field with default value
      add :status, :string, default: "active", null: false
      
      # Nullable field
      add :description, :text, null: true
      
      # Non-nullable field without default
      add :name, :string, null: false
      
      # Field with numeric default
      add :priority, :integer, default: 1, null: false
      
      # Field with boolean default
      add :is_enabled, :boolean, default: true, null: false
      
      # Field with check constraint
      add :score, :integer, null: false
      
      timestamps()
    end

    # Add check constraint for score field (PostgreSQL syntax)
    create constraint(:metadata_test, :score_range, check: "score >= 0 AND score <= 100")
    
    # Add another check constraint for status
    create constraint(:metadata_test, :valid_status, check: "status IN ('active', 'inactive', 'pending')")

    create index(:metadata_test, [:status])
    create index(:metadata_test, [:name, :priority])
  end
end
