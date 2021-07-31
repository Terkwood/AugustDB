defmodule Compaction do
  @moduledoc """
  SSTable Compaction
  """

  @doc """
  Run compaction on all SSTables
  """
  def run do
    raise "todo"
  end

  defp merge(older_path, newer_path) do
    older_sst = :file.open(older_path, [:read, :binary, {:read_ahead, 100_000}])
    newer_sst = :file.open(newer_path, [:read, :binary, {:read_ahead, 100_000}])

    raise "merge them"

    :file.close(older_sst)
    :file.close(newer_sst)
    raise "close output  file"

    raise "return the path of the output file"
  end
end
