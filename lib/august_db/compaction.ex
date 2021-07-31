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
    output_path = "#{hd(String.split(newer_path, ".sst"))}.merge"

    older_sst = :file.open(older_path, [:read, :binary, {:read_ahead, 100_000}])
    newer_sst = :file.open(newer_path, [:read, :binary, {:read_ahead, 100_000}])
    output_sst = :file.open(output_path, [:append])

    raise "merge them"

    :file.close(older_sst)
    :file.close(newer_sst)
    :file.close(output_sst)

    # return the path of the output file
    output_path
  end

  defp keep_merging(older_sst, newer_sst, output_sst) do
    # :file.read_line()  #  :eof bottom   etc
    raise "todo"
    # :file.write(output_sst, somebytes)
  end
end
