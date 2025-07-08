defmodule Ecto.Relation.Repos.Sqlite.Migrations.CreateBasicTypesTable do
  use Ecto.Migration

  def change do
    create table(:basic_types) do
      add :string_field, :string
      add :integer_field, :integer
      add :float_field, :float
      add :boolean_field, :boolean
      add :binary_field, :binary
      add :bitstring_field, :text  # SQLite doesn't have bitstring, use text

      timestamps()
    end
  end
end
