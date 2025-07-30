# Drops.Relation

[![CI](https://github.com/solnic/drops_relation/actions/workflows/ci.yml/badge.svg)](https://github.com/solnic/drops_relation/actions/workflows/ci.yml) [![Hex pm](https://img.shields.io/hexpm/v/drops_relation.svg?style=flat)](https://hex.pm/packages/drops_relation) [![hex.pm downloads](https://img.shields.io/hexpm/dt/drops_relation.svg?style=flat)](https://hex.pm/packages/drops_relation)

High-level API for defining database relations with automatic schema inference and composable queries.

Drops.Relation automatically introspects database tables, generates Ecto schemas, and provides a convenient query API that feels like working directly with Ecto.Repo while adding powerful composition features.

## Installation

Add `drops_relation` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:drops_relation, "~> 0.1.0"}
  ]
end
```

## Configuration

Configure Drops.Relation in your application config:

```elixir
config :my_app, :drops,
  relation: [
    repo: MyApp.Repo
  ]
```

## Quick Start

```elixir
# Define a relation
defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app

  schema("users", infer: true)
end

# Use it like Ecto.Repo
{:ok, user} = MyApp.Users.insert(%{name: "John", email: "john@example.com"})

user = MyApp.Users.get(1)
users = MyApp.Users.all()
```

## Automatic Schemas

Drops.Relation automatically introspects your database tables and generates Ecto schemas:

```elixir
defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app

  # Automatically infers all columns, types, primary keys, and foreign keys
  schema("users", infer: true)
end

# Access the generated schema
schema = MyApp.Users.schema()

schema[:id]
# %Drops.Relation.Schema.Field{
#   name: :id,
#   type: :integer,
#   source: :id,
#   meta: %{
#     default: nil,
#     index: false,
#     type: :integer,
#     primary_key: true,
#     foreign_key: false,
#     check_constraints: [],
#     index_name: nil,
#     nullable: true
#   }
# }

schema[:email]
# %Drops.Relation.Schema.Field{
#   name: :email,
#   type: :string,
#   source: :email,
#   meta: %{
#     default: nil,
#     index: true,
#     type: :string,
#     primary_key: false,
#     foreign_key: false,
#     check_constraints: [],
#     index_name: "users_email_index",
#     nullable: false
#   }
# }
```

You can also define schemas manually or customize inferred ones:

```elixir
defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app

  schema("users") do
    field(:name, :string)
    field(:email, :string)
    field(:active, :boolean, default: true)

    timestamps()
  end
end
```

## Relation Query API

Drops.Relation provides all the familiar Ecto.Repo functions:

```elixir
# Reading data
user = Users.get(1)                           # Get by primary key
user = Users.get!(1)                          # Get by primary key, raise if not found
user = Users.get_by(email: "john@example.com") # Get by attributes
users = Users.all()                           # Get all records
users = Users.all_by(active: true)            # Get all matching attributes

# Aggregations
count = Users.count()                         # Count all records
avg_age = Users.aggregate(:avg, :age)         # Aggregate functions

# Writing data
{:ok, user} = Users.insert(%{name: "John"})   # Insert with map
{:ok, user} = Users.insert!(changeset)        # Insert with changeset
{:ok, user} = Users.update(user, %{name: "Jane"}) # Update record
{:ok, user} = Users.delete(user)              # Delete record

# Changesets
changeset = Users.changeset(%{name: "John"})  # Create changeset
changeset = Users.changeset(user, %{name: "Jane"}) # Update changeset

# Bulk operations
Users.insert_all([%{name: "Alice"}, %{name: "Bob"}])
Users.update_all([active: false])
Users.delete_all()
```

## Composable Queries

Chain operations together for powerful query composition:

```elixir
# Basic composition
active_users = Users
               |> Users.restrict(active: true)
               |> Users.order(:name)
               |> Enum.to_list()

# Complex restrictions
admins = Users
         |> Users.restrict(role: ["admin", "super_admin"])
         |> Users.restrict(active: true)
         |> Users.order([{:last_login, :desc}, :name])

# Works with any Enum function
user_names = Users
             |> Users.restrict(active: true)
             |> Enum.map(& &1.name)

# Preload associations
users_with_posts = Users
                   |> Users.restrict(active: true)
                   |> Users.preload(:posts)
                   |> Enum.to_list()
```

### Available Operations

- `restrict/2` - Add WHERE conditions (supports lists for IN queries)
- `order/2` - Add ORDER BY clauses (supports atoms, lists, and tuples)
- `preload/2` - Preload associations
- Auto-generated finders like `get_by_email/1`, `get_by_name/1` based on indices

## Custom Queries

Define reusable query functions with the `defquery` macro:

```elixir
defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app

  schema("users", infer: true)

  defquery active() do
    from(u in relation(), where: u.active == true)
  end

  defquery by_role(role) when is_binary(role) do
    from(u in relation(), where: u.role == ^role)
  end

  defquery by_role(roles) when is_list(roles) do
    from(u in relation(), where: u.role in ^roles)
  end

  defquery recent(days \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days, :day)
    from(u in relation(), where: u.inserted_at >= ^cutoff)
  end

  defquery with_posts() do
    from(u in relation(),
         join: p in assoc(u, :posts),
         distinct: u.id)
  end
end
```

### Query Composition

Custom queries are fully composable with built-in operations:

```elixir
# Compose custom queries
recent_admins = Users
                |> Users.active()
                |> Users.by_role("admin")
                |> Users.recent(30)
                |> Users.order(:name)
                |> Enum.to_list()

# Mix with restrict operations
active_users_with_email = Users
                          |> Users.active()
                          |> Users.restrict(email: {:not, nil})
                          |> Users.order(:email)

# Chain multiple custom queries
power_users = Users
              |> Users.active()
              |> Users.with_posts()
              |> Users.recent(90)
              |> Users.count()
```

The `relation()` function inside `defquery` blocks returns the relation module, allowing you to reference the current relation in your Ecto queries.

## Advanced Query Composition

For complex query logic involving multiple conditions and boolean operations, use the `query` macro from `Drops.Relation.Query`:

```elixir
defmodule MyApp.Users do
  use Drops.Relation, otp_app: :my_app
  import Drops.Relation.Query

  schema("users", infer: true)

  defquery active() do
    from(u in relation(), where: u.active == true)
  end

  defquery inactive() do
    from(u in relation(), where: u.active == false)
  end

  defquery adult() do
    from(u in relation(), where: u.age >= 18)
  end

  defquery with_email() do
    from(u in relation(), where: not is_nil(u.email))
  end
end
```

### Boolean Logic with AND/OR

The `query` macro supports complex boolean expressions using `and` and `or` operators:

```elixir
# Simple AND operation
adult_active_users = Users
                     |> query([u], u.active() and u.adult())
                     |> Enum.to_list()

# Simple OR operation
active_or_adult = Users
                  |> query([u], u.active() or u.adult())
                  |> Enum.to_list()

# Complex nested conditions
complex_query = Users
                |> query([u],
                  (u.active() and u.adult()) or
                  (u.inactive() and u.with_email())
                )
                |> Users.order(:name)
                |> Enum.to_list()
```

### Mixing Built-in and Custom Operations

Combine auto-generated functions like `restrict/2` and `get_by_*/1` with custom queries:

```elixir
# Mix restrict with custom queries
filtered_users = Users
                 |> query([u], u.active() and u.restrict(role: ["admin", "user"]))
                 |> Enum.to_list()

# Combine auto-generated finders with custom logic
specific_users = Users
                 |> query([u],
                   u.get_by_name("John") or
                   (u.active() and u.restrict(email: "admin@example.com"))
                 )
                 |> Enum.to_list()

# Multiple field restrictions with boolean logic
admin_users = Users
              |> query([u],
                u.restrict(name: ["Alice", "Bob"]) and
                u.active() and
                u.with_email()
              )
              |> Users.order(:name)
              |> Enum.to_list()
```

### Advanced Composition Patterns

Chain multiple OR operations and apply ordering:

```elixir
# Multiple OR conditions
priority_users = Users
                 |> query([u],
                   u.get_by_name("CEO") or
                   u.get_by_name("CTO") or
                   u.restrict(role: "admin")
                 )
                 |> Users.order([{:role, :desc}, :name])
                 |> Enum.to_list()

# Complex nested AND/OR with post-query operations
result = Users
         |> query([u],
           ((u.active() and u.adult()) or (u.inactive() and u.with_email())) and
           u.restrict(department: ["engineering", "product"])
         )
         |> Users.order(desc: :created_at)
         |> Enum.take(10)
```

### Query Syntax

The `query` macro uses Ecto-style variable bindings:

- `[u]` - Single binding variable for the relation
- `u.function_name()` - Calls relation functions on the binding
- `and`/`or` - Boolean operators for combining conditions
- Parentheses for grouping complex expressions

All query operations return relation structs that can be further composed with other operations like `order/2`, `preload/2`, or used with `Enum` functions.
