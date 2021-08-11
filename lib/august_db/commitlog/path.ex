defmodule CommitLog.Path do
  @doc """
  Generates a new file name for a commit log entry.
  Since these files may persist across restarts of the
  application, we use system time instead of monotonic time.
  """
  def new() do
    "commit-#{:erlang.system_time()}.log"
  end
end
