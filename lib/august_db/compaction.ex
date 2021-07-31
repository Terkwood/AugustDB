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

  defp merge(_older, _newer) do
    raise "todo"

    raise "return the path of the output file"
  end
end
