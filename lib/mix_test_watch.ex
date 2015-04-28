defmodule Mix.Tasks.Test.Watch do
  use Mix.Task
  use GenServer

  def run(args) do
    # If MIX_ENV not setted and there is no prefered env, should test setted, as mix do
    if is_nil(System.get_env("MIX_ENV")) && (env = preferred_cli_env(:test)) do
      Mix.env(env)
    end
    setup(args)
    :timer.sleep :infinity
  end

  defp preferred_cli_env(task) do
    Mix.Project.config[:preferred_cli_env][task] || :test
  end

  def setup(args) do
    Application.start :fs
    GenServer.start_link( __MODULE__, args, name: __MODULE__ )
  end

  def init(args) do
    :fs.subscribe
    {:ok, args}
  end

  def handle_info({_pid, {:fs, :file_event}, {path, _event}}, args) do
    path = to_string path
    if watching?(path) do run_tests(args) end
    {:noreply, args}
  end

  defp watching?(path) do
    Regex.match?( ~r/\.exs?\z/i, path )
  end

  defp run_tests(args) do
    IO.puts "Running tests..."

    project = Mix.Project.config
    test_paths = project[:test_paths] || ["test"]

    test_files = Mix.Utils.extract_files(test_paths, "*") |> Enum.map(&Path.expand/1)
    # to force recompilation of test modules, we need to unload files on code_server
    :elixir_code_server.cast({:unload_files, test_files})
    ["loadpaths", "deps.loadpaths", "test"] |> Enum.map(&Mix.Task.reenable/1)
    Mix.Task.run("test", args)
    # As the configuration will grow indefinitly, we cut it after each run
    :elixir_config.put(:at_exit, [])
  end
end
