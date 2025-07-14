- [x] `Drops.Relation.Application` - 100.0%
  - [x] `start/2` - 100.0%

- [x] `Drops.Relation.Compilers.SqliteSchemaCompiler` - 100.0%
  - [ ] `visit/3` - 0.0%

- [x] `Drops.Relation.Compilers.PostgresSchemaCompiler` - 100.0%
  - [ ] `visit/3` - 0.0%
  - [ ] `visit/4` - 0.0%

- [ ] `Drops.Relation.Compilers.EctoCompiler` - 92.0%
  - [ ] `visit/2` - 88.9%

- [ ] `Drops.Relation` - 91.7%
  - [x] `__define_relation__/2` - 100.0%
  - [ ] `new/3` - 0.0%
  - [ ] `__schema__/1` - 0.0%
  - [ ] `__schema__/2` - 0.0%
  - [ ] `schema/0` - 0.0%
  - [ ] `restrict/1` - 0.0%
  - [ ] `restrict/2` - 0.0%
  - [ ] `ecto_schema/1` - 0.0%
  - [ ] `ecto_schema/2` - 0.0%
  - [ ] `association/1` - 0.0%
  - [ ] `associations/0` - 0.0%
  - [ ] `struct/1` - 0.0%
  - [ ] `preload/1` - 0.0%
  - [x] `preload/2` - 100.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 0.0%
  - [x] `to_query/1` - 100.0%

- [ ] `Drops.SQL.Compilers.Sqlite` - 89.3%
  - [ ] `visit/3` - 90.0%

- [ ] `Drops.SQL.Compilers.Postgres` - 86.7%
  - [ ] `visit/3` - 0.0%

- [ ] `Drops.Relation.Cache` - 86.0%
  - [x] `maybe_get_cached_schema/2` - 100.0%
  - [ ] `get_cached_schema/2` - 72.7%
  - [ ] `get_or_infer/2` - 0.0%
  - [x] `cache_schema/3` - 100.0%
  - [x] `clear_repo_cache/1` - 100.0%
  - [x] `clear_all/0` - 100.0%
  - [ ] `warm_up/2` - 0.0%
  - [ ] `refresh/2` - 94.4%
  - [ ] `get_cache_file_path/2` - 95.0%

- [ ] `Drops.Relation.Compilers.CodeCompiler` - 82.6%
  - [x] `visit/2` - 100.0%
  - [x] `visit/3` - 100.0%
  - [x] `visit/5` - 100.0%
  - [ ] `visit/4` - 0.0%
  - [ ] `visit/0` - 0.0%
  - [ ] `visit/6` - 0.0%

- [ ] `Drops.SQL.Postgres` - 81.8%
  - [ ] `introspect_table/2` - 81.8%

- [ ] `Drops.SQL.Sqlite` - 79.6%
  - [ ] `introspect_table/2` - 79.6%

- [ ] `Drops.Relation.Schema.Serializable` - 78.3%
  - [ ] `encode/2` - 0.0%
  - [ ] `name/0` - 0.0%
  - [ ] `load/1` - 0.0%
  - [ ] `load/2` - 0.0%
  - [ ] `dump/1` - 0.0%
  - [ ] `dump/2` - 0.0%
  - [ ] `load/4` - 0.0%

- [ ] `Drops.SQL.Database` - 70.0%
  - [ ] `introspect_table/2` - 0.0%
  - [ ] `opts/0` - 0.0%
  - [ ] `adapter/0` - 0.0%
  - [ ] `table/2` - 0.0%
  - [ ] `compile_table/3` - 71.4%

- [ ] `Drops.Relation.Schema.Patcher` - 68.9%
  - [x] `patch_schema_module/3` - 100.0%
  - [x] `update_attributes/2` - 100.0%
  - [ ] `update_schema_block/3` - 67.0%

- [ ] `Drops.SQL.Database.Table` - 65.2%
  - [x] `fetch/2` - 100.0%
  - [ ] `get_and_update/3` - 83.3%
  - [x] `pop/2` - 100.0%
  - [x] `new/6` - 100.0%
  - [x] `from_introspection/5` - 100.0%
  - [ ] `get_column/2` - 0.0%
  - [ ] `column_names/1` - 0.0%
  - [ ] `primary_key_column_names/1` - 0.0%
  - [ ] `foreign_key_column_names/1` - 0.0%
  - [ ] `primary_key_column?/2` - 0.0%
  - [ ] `foreign_key_column?/2` - 0.0%
  - [ ] `get_foreign_key_for_column/2` - 0.0%

- [ ] `Drops.Relation.Compilers.SchemaCompiler` - 60.0%
  - [ ] `visit/2` - 0.0%
  - [ ] `opts/0` - 0.0%
  - [ ] `process/2` - 0.0%
  - [ ] `visit/3` - 0.0%

- [ ] `Drops.Relation.Generator` - 57.6%
  - [ ] `generate_schema_module/3` - 83.3%
  - [ ] `generate_module_content/3` - 91.7%
  - [ ] `schema_module/3` - 0.0%
  - [ ] `generate_schema_module_string/3` - 0.0%
  - [ ] `generate_schema_module_body/3` - 0.0%
  - [ ] `generate_module_body_content/2` - 0.0%
  - [x] `sync_schema_content/3` - 100.0%
  - [x] `extract_module_name/1` - 100.0%
  - [ ] `generate_schema_parts/2` - 0.0%
  - [x] `generate_schema_ast_from_schema/1` - 100.0%
  - [x] `schema_from_block/2` - 100.0%
  - [ ] `update_schema_with_zipper/3` - 40.7%

- [ ] `Drops.Relation.Schema.Field` - 55.2%
  - [x] `new/3` - 100.0%
  - [ ] `new/5` - 0.0%
  - [ ] `merge/2` - 75.0%
  - [ ] `same_name?/2` - 0.0%
  - [x] `matches_name?/2` - 100.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [x] `reduce/3` - 100.0%

- [ ] `Drops.Relation.Schema` - 54.7%
  - [x] `new/5` - 100.0%
  - [x] `new/1` - 100.0%
  - [x] `empty/1` - 100.0%
  - [ ] `merge/2` - 87.5%
  - [x] `find_field/2` - 100.0%
  - [ ] `primary_key_field?/2` - 0.0%
  - [ ] `foreign_key_field?/2` - 0.0%
  - [ ] `get_foreign_key/2` - 0.0%
  - [x] `composite_primary_key?/1` - 100.0%
  - [ ] `field_names/1` - 0.0%
  - [ ] `foreign_key_field_names/1` - 0.0%
  - [ ] `source_table/1` - 0.0%
  - [ ] `fetch/2` - 66.7%
  - [ ] `get_and_update/3` - 0.0%
  - [ ] `pop/2` - 0.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 80.0%

- [ ] `Drops.Relation.Schema.PrimaryKey` - 54.2%
  - [x] `new/1` - 100.0%
  - [x] `composite?/1` - 100.0%
  - [ ] `present?/1` - 0.0%
  - [x] `field_names/1` - 100.0%
  - [x] `merge/2` - 100.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [x] `reduce/3` - 100.0%

- [ ] `Drops.SQL.Database.PrimaryKey` - 44.4%
  - [x] `new/1` - 100.0%
  - [x] `from_columns/1` - 100.0%
  - [ ] `composite?/1` - 0.0%
  - [ ] `present?/1` - 0.0%
  - [ ] `column_names/1` - 0.0%
  - [ ] `includes_column?/2` - 0.0%
  - [ ] `column_count/1` - 0.0%

- [ ] `Drops.SQL.Database.Column` - 40.0%
  - [x] `new/3` - 100.0%
  - [ ] `primary_key?/1` - 0.0%
  - [ ] `nullable?/1` - 0.0%
  - [ ] `has_default?/1` - 0.0%
  - [ ] `has_check_constraints?/1` - 0.0%

- [ ] `Drops.Relation.Query` - 39.8%
  - [x] `generate_functions/2` - 100.0%
  - [ ] `get/3` - 85.7%
  - [ ] `get!/3` - 0.0%
  - [ ] `get_by/3` - 85.7%
  - [ ] `get_by!/3` - 0.0%
  - [x] `all/2` - 100.0%
  - [ ] `one/2` - 0.0%
  - [ ] `one!/2` - 0.0%
  - [ ] `insert/2` - 88.9%
  - [ ] `insert!/2` - 0.0%
  - [x] `update/2` - 100.0%
  - [ ] `update!/2` - 0.0%
  - [x] `delete/2` - 100.0%
  - [ ] `delete!/2` - 0.0%
  - [ ] `count/3` - 85.7%
  - [ ] `first/2` - 0.0%
  - [ ] `last/2` - 0.0%
  - [ ] `get_by_field/3` - 0.0%
  - [ ] `get/2` - 0.0%
  - [ ] `get!/2` - 0.0%
  - [ ] `get_by/2` - 0.0%
  - [ ] `get_by!/2` - 0.0%
  - [ ] `count/2` - 0.0%
  - [ ] `unquote/1` - 0.0%

- [ ] `Drops.Relation.Config` - 25.0%
  - [x] `validate!/0` - 100.0%
  - [ ] `validate!/1` - 60.0%
  - [x] `persist/1` - 100.0%
  - [ ] `schema_cache/0` - 0.0%
  - [ ] `put_config/2` - 0.0%
  - [ ] `update/2` - 0.0%

- [ ] `Drops.Relation.Schema.Index` - 20.0%
  - [x] `new/4` - 100.0%
  - [x] `composite?/1` - 100.0%
  - [x] `field_names/1` - 100.0%
  - [ ] `covers_field?/2` - 0.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 0.0%

- [ ] `Drops.Relation.Schema.Indices` - 18.2%
  - [x] `new/1` - 100.0%
  - [ ] `add_index/2` - 0.0%
  - [ ] `find_by_field/2` - 0.0%
  - [ ] `unique_indices/1` - 0.0%
  - [ ] `composite_indices/1` - 0.0%
  - [x] `empty?/1` - 100.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 0.0%

- [ ] `Drops.SQL.Database.ForeignKey` - 16.7%
  - [x] `new/0` - 100.0%
  - [ ] `composite?/1` - 0.0%
  - [ ] `column_names/1` - 0.0%
  - [ ] `referenced_column_names/1` - 0.0%
  - [ ] `includes_column?/2` - 0.0%
  - [ ] `column_count/1` - 0.0%

- [ ] `Drops.SQL.Database.Index` - 14.3%
  - [x] `new/3` - 100.0%
  - [ ] `composite?/1` - 0.0%
  - [ ] `unique?/1` - 0.0%
  - [ ] `partial?/1` - 0.0%
  - [ ] `column_names/1` - 0.0%
  - [ ] `includes_column?/2` - 0.0%
  - [ ] `column_count/1` - 0.0%

- [ ] `Drops.Relation.Schema.ForeignKey` - 11.1%
  - [x] `new/3` - 100.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 0.0%

- [ ] `Mix.Tasks.Drops.Relation.RefreshCache` - 0.0%
  - [ ] `run/1` - 0.0%

- [ ] `Drops.SQL.Compiler` - 0.0%
  - [ ] `visit/3` - 0.0%
  - [ ] `opts/0` - 0.0%
  - [ ] `process/2` - 0.0%
  - [ ] `visit/2` - 0.0%

- [ ] `Drops.Relation.Composite` - 0.0%
  - [ ] `new/4` - 0.0%
  - [ ] `infer_association/2` - 0.0%
  - [ ] `to_query/1` - 0.0%
  - [ ] `count/1` - 0.0%
  - [ ] `member?/2` - 0.0%
  - [ ] `slice/1` - 0.0%
  - [ ] `reduce/3` - 0.0%

- [ ] `Mix.Tasks.Drops.Relation.GenSchemas` - 0.0%
  - [ ] `info/2` - 0.0%
  - [ ] `igniter/1` - 0.0%

- [ ] `Drops.SQL.Types.Sqlite` - 0.0%
  - [ ] `to_ecto_type/2` - 0.0%
  - [ ] `to_ecto_type/1` - 0.0%

- [ ] `Drops.SQL.Types.Postgres` - 0.0%
  - [ ] `to_ecto_type/2` - 0.0%
  - [ ] `to_ecto_type/1` - 0.0%

- [ ] `Mix.Tasks.Drops.Relation.DevSetup` - 0.0%
  - [ ] `run/1` - 0.0%
