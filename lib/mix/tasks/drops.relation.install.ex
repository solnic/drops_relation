defmodule Mix.Tasks.Drops.Relation.Install do
  @moduledoc """
  Installs Drops.Relation in your project by updating mix.exs aliases.

  This task automatically adds the `drops.relation.refresh_cache` task to your
  Ecto aliases to ensure the Drops.Relation cache is refreshed whenever you
  run migrations, rollbacks, or load database dumps.

  ## Usage

      mix drops.relation.install

  ## What it does

  This task will update your `mix.exs` file to add the following aliases:

  - `"ecto.migrate": ["ecto.migrate", "drops.relation.refresh_cache"]`
  - `"ecto.rollback": ["ecto.rollback", "drops.relation.refresh_cache"]`
  - `"ecto.load": ["ecto.load", "drops.relation.refresh_cache"]`

  If these aliases already exist, they will be updated to include the cache refresh task.
  If they don't exist, they will be created.

  ## Notes

  - This task uses Igniter to safely modify your mix.exs file
  - Existing aliases will be preserved and extended
  - The task is idempotent - running it multiple times is safe
  """

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :drops_relation,
      example: "mix drops.relation.install",
      positional: [],
      schema: [],
      aliases: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_ecto_migrate_alias()
    |> add_ecto_rollback_alias()
    |> add_ecto_load_alias()
  end

  # Private functions

  defp add_ecto_migrate_alias(igniter) do
    add_or_update_alias(igniter, "ecto.migrate", "ecto.migrate")
  end

  defp add_ecto_rollback_alias(igniter) do
    add_or_update_alias(igniter, "ecto.rollback", "ecto.rollback")
  end

  defp add_ecto_load_alias(igniter) do
    add_or_update_alias(igniter, "ecto.load", "ecto.load")
  end

  defp add_or_update_alias(igniter, alias_name, base_command) do
    alias_atom = String.to_atom(alias_name)

    # Update the specific alias within the aliases function
    # Igniter will create the aliases function if it doesn't exist
    Igniter.Project.MixProject.update(
      igniter,
      :aliases,
      [alias_atom],
      fn current_value ->
        case current_value do
          nil ->
            # Alias doesn't exist, create it
            {:ok, {:code, [base_command, "drops.relation.refresh_cache"]}}

          existing_list when is_list(existing_list) ->
            # Alias exists as a list, add our task if not already present
            if "drops.relation.refresh_cache" in existing_list do
              {:ok, current_value}
            else
              {:ok, {:code, existing_list ++ ["drops.relation.refresh_cache"]}}
            end

          existing_string when is_binary(existing_string) ->
            # Alias exists as a string, convert to list and add our task
            {:ok, {:code, [existing_string, "drops.relation.refresh_cache"]}}

          _ ->
            # Unknown format, replace with our desired format
            {:ok, {:code, [base_command, "drops.relation.refresh_cache"]}}
        end
      end
    )
  end
end
