defmodule Startup do
  @moduledoc """
  Commit log / memtable / SSTable initialization procedures.
  """

  @doc """
    1. Touch the commit log so that we can receive writes.
    2. Replay any stale commit log entries into memory. This lets us recover from crashes
    3. Flush memtable to disk. Just to make sure it's written down. It will also clear the old commit log.
  """
  def init do
    CommitLog.touch()
    CommitLog.replay()
    Memtable.flush()
  end
end
