defmodule Ecto.Relation.Repos.Sqlite.Migrations.CreateAssociationsTables do
  use Ecto.Migration

  def change do
    # Create association_parents table first (referenced by associations)
    create table(:association_parents) do
      add :description, :string

      timestamps()
    end

    # Create associations table
    create table(:associations) do
      add :name, :string
      add :parent_id, references(:association_parents, on_delete: :delete_all)

      timestamps()
    end

    # Create association_items table
    create table(:association_items) do
      add :title, :string
      add :association_id, references(:associations, on_delete: :delete_all)

      timestamps()
    end
  end
end
