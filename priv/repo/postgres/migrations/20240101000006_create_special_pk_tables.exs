defmodule Test.Repos.Postgres.Migrations.CreateSpecialPkTables do
  use Ecto.Migration

  def change do
    # Custom primary key table
    create table(:custom_pk, primary_key: false) do
      add(:uuid, :binary_id, primary_key: true)
      add(:name, :string)

      timestamps()
    end

    # No primary key table
    create table(:no_pk, primary_key: false) do
      add(:name, :string)
      add(:value, :integer)

      timestamps()
    end

    # Composite primary key table
    create table(:composite_pk, primary_key: false) do
      add(:part1, :string, primary_key: true)
      add(:part2, :integer, primary_key: true)
      add(:data, :string)

      timestamps()
    end
  end
end
