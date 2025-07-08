# Ecto.Relation

This module provides comprehensive metadata extraction capabilities for Ecto schemas, enabling programmatic access to primary keys, foreign keys, field information, and database indices.

## Overview

The schema metadata system consists of several interconnected modules:

- **`Drops.Relation.Schema`** - Main container for complete schema metadata
- **`Drops.Relation.Schema.MetadataExtractor`** - Central extraction engine
- **`Drops.Relation.Schema.PrimaryKey`** - Primary key information
- **`Drops.Relation.Schema.ForeignKey`** - Foreign key relationships
- **`Drops.Relation.Schema.Index`** - Individual database index
- **`Drops.Relation.Schema.Indices`** - Collection of indices with query methods
- **`Drops.Relation.SQL.Introspector`** - Database-level introspection

## Quick Start

### Basic Usage

```elixir
# Extract complete metadata from an Ecto schema
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User)

# Access metadata
schema.source                    # "users"
schema.primary_key.fields        # [:id]
schema.foreign_keys             # []
schema.fields                   # [%{name: :id, type: :integer, ...}, ...]
```

### With Database Introspection

```elixir
# Include database index information
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User, MyApp.Repo)

# Check for indices
unless Indices.empty?(schema.indices) do
  IO.puts("Found #{Indices.count(schema.indices)} indices")
end
```

## Core Concepts

### Primary Keys

The system supports single, composite, and missing primary keys:

```elixir
# Single primary key
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User)
schema.primary_key.fields  # [:id]

# Composite primary key
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.UserRole)
schema.primary_key.fields  # [:user_id, :role_id]

# Check properties
Schema.primary_key_field?(schema, :id)        # true
Schema.composite_primary_key?(schema)         # false
```

### Foreign Keys

Foreign keys are extracted from `belongs_to` associations:

```elixir
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.Post)

# Check for foreign keys
if Schema.foreign_key_field?(schema, :user_id) do
  fk = Schema.get_foreign_key(schema, :user_id)
  IO.puts("References #{fk.references_table}.#{fk.references_field}")
end

# Get all foreign key fields
fk_fields = Schema.foreign_key_field_names(schema)  # [:user_id, :category_id]
```

### Database Indices

Index information is extracted from the database when a repository is provided:

```elixir
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User, MyApp.Repo)

# Find indices covering a specific field
email_indices = Indices.find_by_field(schema.indices, :email)

# Filter by properties
unique_indices = Indices.unique_indices(schema.indices)
composite_indices = Indices.composite_indices(schema.indices)

# Check index properties
for index <- email_indices do
  IO.puts("Index: #{index.name}, Unique: #{index.unique}")
end
```

### Field Metadata

Detailed field information including types and sources:

```elixir
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User)

# Find specific field
email_field = Schema.find_field(schema, :email)
# Returns: %{name: :email, type: :string, ecto_type: :string, source: :email}

# Get all field names
field_names = Schema.field_names(schema)  # [:id, :name, :email, ...]
```

## Advanced Usage

### Custom Metadata Extraction

```elixir
# Extract individual components
primary_key = MetadataExtractor.extract_primary_key(MyApp.User)
foreign_keys = MetadataExtractor.extract_foreign_keys(MyApp.Post)
fields = MetadataExtractor.extract_fields(MyApp.User)

# Database-only index extraction
indices = Drops.Relation.SQL.Introspector.get_table_indices(MyApp.Repo, "users")
```

### Working with Associations

```elixir
# Schema with multiple associations
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.Post)

# Analyze foreign key relationships
for fk <- schema.foreign_keys do
  IO.puts("#{fk.field} -> #{fk.references_table}.#{fk.references_field}")
  IO.puts("Association: #{fk.association_name}")
end
```

### Index Analysis

```elixir
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User, MyApp.Repo)

# Comprehensive index analysis
indices = schema.indices

IO.puts("Total indices: #{Indices.count(indices)}")
IO.puts("Unique indices: #{length(Indices.unique_indices(indices))}")
IO.puts("Composite indices: #{length(Indices.composite_indices(indices))}")

# Check coverage for specific fields
critical_fields = [:email, :username, :phone]
for field <- critical_fields do
  field_indices = Indices.find_by_field(indices, field)
  if length(field_indices) > 0 do
    IO.puts("#{field} is indexed (#{length(field_indices)} indices)")
  else
    IO.puts("⚠️  #{field} is not indexed")
  end
end
```

## Database Support

### SQLite (Fully Supported)
- Primary key detection
- Foreign key extraction via associations
- Index introspection via PRAGMA commands
- Unique and composite index support

### PostgreSQL (Supported)
- Primary key detection
- Foreign key extraction via associations
- Index introspection via system catalogs
- Advanced index type detection

### Other Databases
The system is designed with an adapter pattern to support additional databases. Contributions welcome!

## Error Handling

The system gracefully handles various edge cases:

```elixir
# Schema without primary key
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.LogEntry)
refute Schema.primary_key_field?(schema, :any_field)

# Schema without associations
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.SimpleModel)
assert schema.foreign_keys == []

# Database connection issues
schema = Drops.Relation.Schema.from_ecto_schema(MyApp.User, nil)
assert Indices.empty?(schema.indices)  # No repo = no indices
```

## Performance Considerations

- **Ecto Reflection**: Fast, uses compiled schema information
- **Database Introspection**: Requires database queries, cache results when possible
- **Memory Usage**: Metadata structures are lightweight
- **Lazy Loading**: Index information only loaded when repository provided

## Testing

The system includes comprehensive tests covering:

- All primary key scenarios (single, composite, missing)
- Foreign key detection from various association types
- Database index introspection for multiple database types
- Edge cases and error conditions
- Performance and memory usage

Run tests with:
```bash
mix test test/drops/relation/schema/
```

## Contributing

When adding new features:

1. Follow the existing modular architecture
2. Add comprehensive tests including edge cases
3. Update documentation with examples
4. Consider database compatibility
5. Maintain type safety with proper typespecs

## License

This module is part of the Drops library and follows the same license terms.
