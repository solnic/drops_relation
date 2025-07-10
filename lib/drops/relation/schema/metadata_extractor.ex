defmodule Drops.Relation.Schema.MetadataExtractor do
  @moduledoc """
  Comprehensive metadata extraction from Ecto schemas and database introspection.

  This module combines Ecto schema reflection with database-level introspection
  to extract complete metadata about tables including primary keys, foreign keys,
  field types, and indices.

  ## Usage

      # Extract all metadata for a schema
      metadata = Drops.Relation.Schema.MetadataExtractor.extract_metadata(
        MyApp.User,
        MyApp.Repo
      )

      # Extract specific metadata types
      primary_key = Drops.Relation.Schema.MetadataExtractor.extract_primary_key(MyApp.User)
      foreign_keys = Drops.Relation.Schema.MetadataExtractor.extract_foreign_keys(MyApp.User)
  """

  alias Drops.Relation.Schema.{
    PrimaryKey,
    ForeignKey,
    Indices,
    Field
  }

  alias Drops.SQL.Introspection

  @type field_metadata :: %{
          name: atom(),
          type: atom(),
          ecto_type: term(),
          source: atom()
        }

  @type schema_metadata :: %{
          source: String.t(),
          primary_key: PrimaryKey.t(),
          foreign_keys: [ForeignKey.t()],
          fields: [Field.t()],
          indices: Indices.t(),
          associations: [atom()],
          virtual_fields: [atom()]
        }

  @doc """
  Extracts complete metadata for an Ecto schema.

  ## Parameters

  - `schema_module` - The Ecto schema module
  - `repo` - The Ecto repository (optional, required for index introspection)

  ## Returns

  Returns a map containing all extracted metadata.

  ## Examples

      iex> metadata = Drops.Relation.Schema.MetadataExtractor.extract_metadata(MyApp.User, MyApp.Repo)
      iex> metadata.primary_key
      %Drops.Relation.Schema.PrimaryKey{fields: [:id]}
  """
  @spec extract_metadata(module(), module() | nil) :: schema_metadata()
  def extract_metadata(schema_module, repo \\ nil) when is_atom(schema_module) do
    source = schema_module.__schema__(:source)

    # Extract metadata from Ecto schema
    primary_key = extract_primary_key(schema_module)
    foreign_keys = extract_foreign_keys(schema_module)
    fields = extract_fields(schema_module)
    associations = extract_associations(schema_module)
    virtual_fields = schema_module.__schema__(:virtual_fields)

    # Extract indices from database if repo is provided
    indices =
      if repo do
        case extract_indices(schema_module, repo) do
          {:ok, indices} -> indices
          {:error, _} -> Indices.new()
        end
      else
        Indices.new()
      end

    %{
      source: source,
      primary_key: primary_key,
      foreign_keys: foreign_keys,
      fields: fields,
      indices: indices,
      associations: associations,
      virtual_fields: virtual_fields
    }
  end

  @doc """
  Extracts primary key information from an Ecto schema.

  ## Examples

      iex> Drops.Relation.Schema.MetadataExtractor.extract_primary_key(MyApp.User)
      %Drops.Relation.Schema.PrimaryKey{fields: [:id]}
  """
  @spec extract_primary_key(module()) :: PrimaryKey.t()
  def extract_primary_key(schema_module) when is_atom(schema_module) do
    PrimaryKey.from_ecto_schema(schema_module)
  end

  @doc """
  Extracts foreign key information from an Ecto schema.

  ## Examples

      iex> Drops.Relation.Schema.MetadataExtractor.extract_foreign_keys(MyApp.Post)
      [%Drops.Relation.Schema.ForeignKey{field: :user_id, ...}]
  """
  @spec extract_foreign_keys(module()) :: [ForeignKey.t()]
  def extract_foreign_keys(schema_module) when is_atom(schema_module) do
    ForeignKey.from_ecto_schema(schema_module)
  end

  @doc """
  Extracts field metadata from an Ecto schema.

  ## Examples

      iex> fields = Drops.Relation.Schema.MetadataExtractor.extract_fields(MyApp.User)
      iex> Enum.find(fields, & &1.name == :email)
      %Drops.Relation.Schema.Field{name: :email, type: :string, ecto_type: :string, source: :email}
  """
  @spec extract_fields(module()) :: [Field.t()]
  def extract_fields(schema_module) when is_atom(schema_module) do
    fields = schema_module.__schema__(:fields)

    for field <- fields do
      ecto_type = schema_module.__schema__(:type, field)
      source = schema_module.__schema__(:field_source, field) || field

      Field.new(
        field,
        normalize_ecto_type(ecto_type),
        ecto_type,
        source
      )
    end
  end

  @doc """
  Extracts index information from the database for an Ecto schema.

  ## Parameters

  - `schema_module` - The Ecto schema module
  - `repo` - The Ecto repository module

  ## Returns

  Returns `{:ok, %Indices{}}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Drops.Relation.Schema.MetadataExtractor.extract_indices(MyApp.User, MyApp.Repo)
      {:ok, %Drops.Relation.Schema.Indices{indices: [...]}}
  """
  @spec extract_indices(module(), module()) :: {:ok, Indices.t()} | {:error, term()}
  def extract_indices(schema_module, repo)
      when is_atom(schema_module) and is_atom(repo) do
    table_name = schema_module.__schema__(:source)
    Introspection.get_table_indices(repo, table_name)
  end

  @doc """
  Checks if a field is a foreign key based on extracted metadata.

  ## Examples

      iex> foreign_keys = Drops.Relation.Schema.MetadataExtractor.extract_foreign_keys(MyApp.Post)
      iex> Drops.Relation.Schema.MetadataExtractor.foreign_key?(foreign_keys, :user_id)
      true
  """
  @spec foreign_key?([ForeignKey.t()], atom()) :: boolean()
  def foreign_key?(foreign_keys, field_name)
      when is_list(foreign_keys) and is_atom(field_name) do
    Enum.any?(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Finds the foreign key information for a specific field.

  ## Examples

      iex> foreign_keys = Drops.Relation.Schema.MetadataExtractor.extract_foreign_keys(MyApp.Post)
      iex> Drops.Relation.Schema.MetadataExtractor.find_foreign_key(foreign_keys, :user_id)
      %Drops.Relation.Schema.ForeignKey{field: :user_id, ...}
  """
  @spec find_foreign_key([ForeignKey.t()], atom()) :: ForeignKey.t() | nil
  def find_foreign_key(foreign_keys, field_name)
      when is_list(foreign_keys) and is_atom(field_name) do
    Enum.find(foreign_keys, &(&1.field == field_name))
  end

  @doc """
  Extracts association information from an Ecto schema module.

  Returns a list of Ecto association structs (BelongsTo, Has, ManyToMany, etc.)
  containing complete metadata about each association.

  ## Parameters

  - `schema_module` - An Ecto schema module

  ## Returns

  A list of Ecto association structs with complete metadata.

  ## Examples

      iex> associations = Drops.Relation.Schema.MetadataExtractor.extract_associations(MyApp.Post)
      iex> length(associations)
      2
      iex> hd(associations)
      %Ecto.Association.BelongsTo{field: :user, owner: MyApp.Post, ...}
  """
  @spec extract_associations(module()) :: [
          Ecto.Association.BelongsTo.t()
          | Ecto.Association.Has.t()
          | Ecto.Association.ManyToMany.t()
        ]
  def extract_associations(schema_module) when is_atom(schema_module) do
    association_names = schema_module.__schema__(:associations)

    Enum.map(association_names, fn assoc_name ->
      schema_module.__schema__(:association, assoc_name)
    end)
  end

  # Private helper functions

  # Normalize Ecto types to simpler atoms for easier handling
  defp normalize_ecto_type(ecto_type) do
    case ecto_type do
      :id -> :integer
      :binary_id -> :binary
      {:array, inner_type} -> {:array, normalize_ecto_type(inner_type)}
      {:map, _} -> :map
      type when is_atom(type) -> type
      _ -> :any
    end
  end
end
