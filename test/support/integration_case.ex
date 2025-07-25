defmodule Test.IntegrationCase do
  @moduledoc """
  Test case for integration tests that run mix tasks within the sample_app directory.

  This case provides:
  - Automatic MIX_ENV management
  - Directory cleanup based on tags
  - Helper for running mix tasks in sample_app context
  """

  use ExUnit.CaseTemplate

  @apps_path Path.join([__DIR__, "..", "apps"])

  using do
    quote do
      import Test.IntegrationCase
    end
  end

  setup tags do
    # Store original environment
    original_cwd = File.cwd!()
    original_env = System.get_env("MIX_ENV")

    app = Map.get(tags, :app, "sample")

    app_path = Path.join(@apps_path, app)

    # Change to sample_app directory
    File.cd!(app_path)

    # Set MIX_ENV to dev to avoid test database ownership issues
    System.put_env("MIX_ENV", "dev")

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

      # Clean up directories after test
      clean_directories(clean_dirs)

      # Clear cache after test
      clear_cache()
    end)

    :ok
  end

  @doc """
  Runs a mix task in the sample_app context.

  ## Examples

      run_task("drops.relation.gen_schemas --app Sample --repo Sample.Repo")
      run_task("drops.relation.refresh_cache --repo Sample.Repo")

  ## Returns

  Returns `{output, exit_code}` tuple where:
  - `output` is the combined stdout/stderr output
  - `exit_code` is the process exit code (0 for success)
  """
  def run_task(task_string) do
    args = String.split(task_string, " ")
    [task_name | task_args] = args

    System.cmd(
      "mix",
      [task_name | task_args],
      env: [{"MIX_ENV", "dev"}],
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

      assert_file_exists("lib/sample_app/schemas/users.ex")
  """
  def assert_file_exists(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    assert File.exists?(full_path), "Expected file to exist: #{relative_path}"
  end

  @doc """
  Asserts that a file does not exist in the current app directory.

  ## Examples

      refute_file_exists("lib/sample_app/schemas/users.ex")
  """
  def refute_file_exists(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    refute File.exists?(full_path), "Expected file to not exist: #{relative_path}"
  end

  @doc """
  Reads a file from the current app directory.

  ## Examples

      content = read_file("lib/sample_app/schemas/users.ex")
  """
  def read_file(relative_path) do
    full_path = Path.join(File.cwd!(), relative_path)
    File.read!(full_path)
  end

  @doc """
  Writes content to a file in the current app directory.

  ## Examples

      write_file("lib/sample_app/schemas/users.ex", schema_content)
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
end
