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

  defp merge(many_paths) when is_list(many_paths) do
    output_path = "#{:erlang.system_time()}.sst"

    many_devices =
      Enum.map(many_paths, fn p -> :file.open(p, [:read, :binary, {:read_ahead, 100_000}]) end)

    output_sst = :file.open(output_path, [:append])

    raise "merge them"

    Enum.map(many_devices, &:file.close(&1))
    :file.close(output_sst)

    # return the path of the output file
    output_path
  end

  defp keep_merging(older_sst, newer_sst, output_sst) do
    # :file.read_line()  #  :eof bottom   etc
    raise "todo"
    # :file.write(output_sst, somebytes)
  end

  defmodule Sort do
    def lowest([{k, v} | newer]) do
      lowest([{k, v} | newer], {k, v})
    end

    def lowest([], {acc_k, acc_v}) do
      {acc_k, acc_v}
    end

    def lowest([{next_k, next_v} | newer], {acc_k, acc_v}) do
      if next_k <= acc_k do
        lowest(newer, {next_k, next_v})
      else
        lowest(newer, {acc_k, acc_v})
      end
    end
  end
end
