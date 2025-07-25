defmodule Test.IntegrationCase do
  @moduledoc """
  Test case for integration tests that run mix tasks within the sample directory.

  This case provides:
  - Automatic MIX_ENV management
  - Directory cleanup based on tags
  - Helper for running mix tasks in sample context
  """

  use ExUnit.CaseTemplate

  @apps_path Path.join([__DIR__, "../..", "test_integration", "apps"])

  using do
    quote do
      import Test.IntegrationCase
    end
  end

  setup tags do
    # Store original environment
    original_cwd = File.cwd!()
    original_env = System.get_env("MIX_ENV")
    original_adapter = System.get_env("ADAPTER")

    app = Map.get(tags, :app, "sample")
    adapter = Map.get(tags, :adapter, String.to_atom(System.get_env("ADAPTER", "sqlite")))

    app_path = Path.join(@apps_path, app)

    # Change to app directory
    File.cd!(app_path)

    # Set MIX_ENV to dev to avoid test database ownership issues
    System.put_env("MIX_ENV", "dev")

    # Set ADAPTER environment variable for the test
    System.put_env("ADAPTER", Atom.to_string(adapter))

    # Clean and recompile when switching adapters to avoid compile-time config issues
    # Always clean and recompile to ensure the correct adapter configuration
    System.cmd("mix", ["deps.clean", "sample", "--build"], env: [{"MIX_ENV", "dev"}])

    System.cmd("mix", ["compile", "--force"],
      env: [{"MIX_ENV", "dev"}, {"ADAPTER", Atom.to_string(adapter)}]
    )

    # Handle file state management
    files_to_restore = Map.get(tags, :files, [])
    original_file_contents = backup_files(files_to_restore)

    # Clean directories if specified in tags
    clean_dirs = Map.get(tags, :clean_dirs, [])
    clean_directories(clean_dirs)

    # Clear the cache to ensure clean state between tests
    clear_cache()

    on_exit(fn ->
      # Restore original working directory
      File.cd!(original_cwd)

      # Restore original MIX_ENV
      if original_env do
        System.put_env("MIX_ENV", original_env)
      else
        System.delete_env("MIX_ENV")
      end

      # Restore original ADAPTER
      if original_adapter do
        System.put_env("ADAPTER", original_adapter)
      else
        System.delete_env("ADAPTER")
      end

      # Change back to app directory for cleanup
      File.cd!(app_path)

      # Restore original file contents
      restore_files(files_to_restore, original_file_contents)

      # Clean up directories after test
      clean_directories(clean_dirs)

      # Clear cache after test
      clear_cache()

      # Restore original working directory again
      File.cd!(original_cwd)
    end)

    :ok
  end

  @doc """
  Runs a mix task in the sample context.

  ## Examples

      run_task("drops.relation.gen_schemas --app Sample")
      run_task("drops.relation.refresh_cache")

  ## Returns

  Returns `{output, exit_code}` tuple where:
  - `output` is the combined stdout/stderr output
  - `exit_code` is the process exit code (0 for success)
  """
  def run_task(task_string) do
    args = String.split(task_string, " ")
    [task_name | task_args] = args

    env = [{"MIX_ENV", "dev"}]

    # Pass through ADAPTER environment variable if set
    env =
      case System.get_env("ADAPTER") do
        nil -> env
        adapter -> [{"ADAPTER", adapter} | env]
      end

    System.cmd(
      "mix",
      [task_name | task_args],
      env: env,
      stderr_to_stdout: true
    )
  end

  @doc """
  Runs a mix task and asserts it succeeds.

  Same as `run_task/1` but automatically asserts the exit code is 0.
  Returns just the output string.
  """
  def run_task!(task_string) do
    {output, exit_code} = run_task(task_string)
    assert exit_code == 0, "Mix task failed with output: #{output}"
    output
  end

  @doc """
  Asserts that a file exists in the current app directory.

  ## Examples

      assert_file_exists("lib/sample/schemas/users.ex")
  """
  def assert_file_exists(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    assert File.exists?(full_path), "Expected file to exist: #{relative_path}"
  end

  @doc """
  Asserts that a file does not exist in the current app directory.

  ## Examples

      refute_file_exists("lib/sample/schemas/users.ex")
  """
  def refute_file_exists(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    refute File.exists?(full_path), "Expected file to not exist: #{relative_path}"
  end

  @doc """
  Reads a file from the current app directory.

  ## Examples

      content = read_file("lib/sample/schemas/users.ex")
  """
  def read_file(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    File.read!(full_path)
  end

  @doc """
  Writes content to a file in the current app directory.

  ## Examples

      write_file("lib/sample/schemas/users.ex", schema_content)
  """
  def write_file(relative_path, content) do
    full_path = Path.join(File.cwd!(), relative_path)
    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, content)
  end

  # Private functions

  defp clean_directories(dirs) do
    Enum.each(dirs, fn dir ->
      full_path = Path.join(File.cwd!(), dir)

      if File.exists?(full_path) do
        File.rm_rf!(full_path)
      end
    end)
  end

  defp clear_cache do
    # Clear the drops_relation cache directory for dev environment
    cache_dir = Path.join(File.cwd!(), "tmp/cache/dev/drops_relation_schema")

    if File.exists?(cache_dir) do
      File.rm_rf!(cache_dir)
    end
  end

  defp backup_files(files) do
    Enum.reduce(files, %{}, fn file_path, acc ->
      full_path = Path.join(File.cwd!(), file_path)

      if File.exists?(full_path) do
        content = File.read!(full_path)
        Map.put(acc, file_path, content)
      else
        Map.put(acc, file_path, :not_found)
      end
    end)
  end

  defp restore_files(files, original_contents) do
    Enum.each(files, fn file_path ->
      full_path = Path.join(File.cwd!(), file_path)

      case Map.get(original_contents, file_path) do
        :not_found ->
          # File didn't exist originally, remove it if it exists now
          if File.exists?(full_path) do
            File.rm!(full_path)
          end

        content when is_binary(content) ->
          # Restore original content
          File.mkdir_p!(Path.dirname(full_path))
          File.write!(full_path, content)

        nil ->
          # No backup found, skip
          :ok
      end
    end)
  end
end
