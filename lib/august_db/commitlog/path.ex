defmodule CommitLog.Path do
  @doc """
  Generates a new file name for a commit log entry.
  Since these files may persist across restarts of the
  application, we use system time instead of monotonic time.
  """
  def new_path() do
    "commit-#{:erlang.system_time()}.log"
  end

  def extract_time(path) do
    String.split(path, ".log") |> hd |> String.split("commit-") |> tl
  end
end
