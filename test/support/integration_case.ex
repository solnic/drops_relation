defmodule Test.IntegrationCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  @apps_path Path.join([__DIR__, "../..", "test_integration", "apps"])

  using do
    quote do
      import Test.IntegrationCase
    end
  end

  setup tags do
    original_cwd = File.cwd!()

    app = Map.get(tags, :app, "sample")
    app_path = Path.join(@apps_path, app)

    File.cd!(app_path)

    files_to_restore = Map.get(tags, :files, [])
    original_file_contents = backup_files(files_to_restore)

    clean_dirs = Map.get(tags, :clean_dirs, [])
    clean_directories(clean_dirs)

    clear_cache()

    on_exit(fn ->
      File.cd!(original_cwd)
      File.cd!(app_path)

      restore_files(files_to_restore, original_file_contents)
      clean_directories(clean_dirs)
      clear_cache()

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

    env = [{"MIX_ENV", "test"}]

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
    cache_dir = Path.join(File.cwd!(), "tmp/cache/test/drops_relation_schema")

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
