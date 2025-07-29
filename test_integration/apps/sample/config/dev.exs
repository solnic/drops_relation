# Stub file for igniter, otherwise this happens:

#  Mix task failed with output: Generating schemas for tables: comments, posts, users
#  Creating or updating schema: Sample.Schemas.Comments
#  ** (File.Error) could not read file "config/dev.exs": no such file or directory
#      (elixir 1.15.8) lib/file.ex:358: File.read!/1
#      (rewrite 1.1.2) lib/rewrite/source.ex:127: Rewrite.Source.read!/2
#      (rewrite 1.1.2) lib/rewrite/source/ex.ex:137: Rewrite.Source.Ex.read!/2
#      (igniter 0.6.10) lib/igniter.ex:648: Igniter.include_existing_file/3
#      (igniter 0.6.10) lib/igniter.ex:1514: Igniter.format/3
#      (elixir 1.15.8) lib/enum.ex:2510: Enum."-reduce/3-lists^foldl/2-0-"/3
#      (drops_relation 0.0.1) lib/mix/tasks/drops.relation.gen_schemas.ex:35: Mix.Tasks.Drops.Relation.GenSchemas.run/1
#      (mix 1.15.8) lib/mix/task.ex:455: anonymous fn/3 in Mix.Task.run_task/5
