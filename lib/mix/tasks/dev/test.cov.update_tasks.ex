if Mix.env() == :test do
  defmodule Mix.Tasks.Test.Coverage.UpdateTasks do
    @moduledoc false

    use Mix.Task

    @shortdoc "Generates test/cov-todo.md from coverage data"

    @coverage_file "cover/excoveralls.json"
    @output_file "test/cov-todo.md"

    @impl Mix.Task
    def run(_args) do
      Mix.shell().info("Analyzing coverage data...")

      case File.read(@coverage_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, coverage_data} ->
              generate_todo_file(coverage_data)

            {:error, reason} ->
              Mix.shell().error("Failed to parse JSON: #{inspect(reason)}")
              {:error, :json_parse_error}
          end

        {:error, reason} ->
          Mix.shell().error("Failed to read #{@coverage_file}: #{inspect(reason)}")
          {:error, :file_read_error}
      end
    end

    defp generate_todo_file(coverage_data) do
      source_files = Map.get(coverage_data, "source_files", [])

      Mix.shell().info("Processing #{length(source_files)} source files...")

      modules_with_coverage =
        source_files
        |> Enum.filter(&is_lib_file?/1)
        |> Enum.map(&extract_module_info/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.coverage_percent, :desc)

      Mix.shell().info("Found #{length(modules_with_coverage)} modules")

      markdown_content = generate_markdown(modules_with_coverage)

      case File.write(@output_file, markdown_content) do
        :ok ->
          Mix.shell().info("Generated #{@output_file}")
          :ok

        {:error, reason} ->
          Mix.shell().error("Failed to write #{@output_file}: #{inspect(reason)}")
          {:error, :file_write_error}
      end
    end

    defp is_lib_file?(%{"name" => name}) do
      String.starts_with?(name, "lib/") and String.ends_with?(name, ".ex")
    end

    defp extract_module_info(%{"name" => file_path, "source" => source, "coverage" => coverage}) do
      case extract_module_name(source) do
        nil ->
          nil

        module_name ->
          functions = extract_public_functions(source, coverage)
          coverage_percent = calculate_coverage_percentage(coverage)

          %{
            name: module_name,
            file_path: file_path,
            coverage_percent: coverage_percent,
            functions: functions
          }
      end
    end

    defp extract_module_name(source) do
      case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)\s+do/, source) do
        [_, module_name] -> module_name
        _ -> nil
      end
    end

    defp extract_public_functions(source, coverage) do
      lines = String.split(source, "\n")

      function_definitions =
        lines
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _index} ->
          # Match public function definitions (def, not defp)
          String.match?(line, ~r/^\s*def\s+[a-zA-Z_][a-zA-Z0-9_?!]*/) and
            not String.match?(line, ~r/^\s*defp\s/)
        end)

      # Calculate function boundaries and coverage
      function_definitions
      |> Enum.with_index()
      |> Enum.map(fn {{line, line_number}, index} ->
        function_name = extract_function_name(line)

        # Find the end of this function
        next_function_line =
          case Enum.at(function_definitions, index + 1) do
            {_, next_line} -> next_line - 1
            # End of file
            nil -> length(lines)
          end

        function_coverage = calculate_function_coverage(coverage, line_number, next_function_line)
        is_covered = function_coverage >= 100.0

        %{
          name: function_name,
          line_number: line_number,
          end_line: next_function_line,
          covered: is_covered,
          coverage_percent: function_coverage
        }
      end)
      |> Enum.reject(&is_nil(&1.name))
      # Remove duplicates
      |> Enum.uniq_by(& &1.name)
    end

    defp extract_function_name(line) do
      # First try to match function with explicit arity (def func/2)
      case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)\s*\/\s*(\d+)/, line) do
        [_, function_name, arity] ->
          "#{function_name}/#{arity}"

        _ ->
          # Try to match function name and count parameters
          case Regex.run(~r/def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)/, line) do
            [_, function_name] ->
              arity = count_function_arity(line)
              "#{function_name}/#{arity}"

            _ ->
              nil
          end
      end
    end

    defp count_function_arity(line) do
      # Simple arity counting - look for parameters between parentheses
      case Regex.run(~r/def\s+[a-zA-Z_][a-zA-Z0-9_?!]*\s*\(([^)]*)\)/, line) do
        [_, params_str] ->
          if String.trim(params_str) == "" do
            0
          else
            # Count commas + 1, but handle default values and complex patterns
            params_str
            |> String.split(",")
            |> length()
          end

        _ ->
          # No parentheses, check if there are parameters after the function name
          case Regex.run(~r/def\s+[a-zA-Z_][a-zA-Z0-9_?!]*\s+(.+)/, line) do
            [_, params] ->
              # Simple heuristic: if there's content after the function name, assume 1+ params
              if String.trim(params) != "" and not String.starts_with?(String.trim(params), "do") do
                # Count spaces/commas as rough arity estimate
                max(1, length(String.split(params, ",")))
              else
                0
              end

            _ ->
              0
          end
      end
    end

    defp calculate_function_coverage(coverage, start_line, end_line) do
      # Calculate coverage percentage for lines within the function body
      # Skip the function definition line itself and focus on the body
      actual_start = start_line + 1

      # Handle edge case where function has no body or end_line is before start_line
      if actual_start > end_line do
        0.0
      else
        function_lines = actual_start..end_line

        relevant_lines =
          function_lines
          |> Enum.map(fn line_num -> Enum.at(coverage, line_num - 1) end)
          # Remove nil values (non-executable lines)
          |> Enum.reject(&is_nil/1)

        if length(relevant_lines) == 0 do
          0.0
        else
          covered_lines =
            relevant_lines
            |> Enum.count(fn
              n when is_integer(n) and n > 0 -> true
              _ -> false
            end)

          (covered_lines / length(relevant_lines) * 100)
          |> Float.round(1)
        end
      end
    end

    defp calculate_coverage_percentage(coverage) do
      relevant_lines =
        coverage
        |> Enum.reject(&is_nil/1)

      if length(relevant_lines) == 0 do
        0.0
      else
        covered_lines =
          relevant_lines
          |> Enum.count(fn
            n when is_integer(n) and n > 0 -> true
            _ -> false
          end)

        (covered_lines / length(relevant_lines) * 100)
        |> Float.round(1)
      end
    end

    defp generate_markdown(modules) do
      content =
        modules
        |> Enum.map(&format_module/1)
        |> Enum.join("\n\n")

      content <> "\n"
    end

    defp format_module(%{name: name, coverage_percent: percent, functions: functions}) do
      checkbox = if percent >= 100.0, do: "x", else: " "
      header = "- [#{checkbox}] `#{name}` - #{percent}%"

      function_lines =
        functions
        |> Enum.map(&format_function/1)
        |> Enum.join("\n")

      if function_lines != "" do
        header <> "\n" <> function_lines
      else
        header
      end
    end

    defp format_function(%{name: name, covered: covered, coverage_percent: coverage_percent}) do
      checkbox = if covered, do: "x", else: " "
      "  - [#{checkbox}] `#{name}` - #{coverage_percent}%"
    end
  end
end
