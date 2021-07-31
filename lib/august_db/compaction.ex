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

  def merge() do
    merge(Enum.sort(Path.wildcard("*.sst")))
  end

  defp merge(many_paths) when is_list(many_paths) do
    output_path = "#{:erlang.system_time()}.sst"

    many_devices =
      Enum.map(many_paths, fn p ->
        {:ok, f} = :file.open(p, [:read, :binary, {:read_ahead, 100_000}])
        f
      end)

    {:ok, output_sst} = :file.open(output_path, [:append])

    many_kv_devices =
      many_devices
      |> Enum.map(fn d ->
        kv_or_eof = parse_tsv(:file.read_line(d))
        {kv_or_eof, d}
      end)
      |> Enum.filter(fn {kv_or_eof, _d} -> kv_or_eof != :eof end)

    plug(many_kv_devices, output_sst)

    Enum.map(many_devices, &:file.close(&1))
    :file.close(output_sst)

    # return the path of the output file
    output_path
  end

  def parse_tsv(:eof) do
    :eof
  end

  @tsv_header_string TSV.header_string()
  def parse_tsv(line) do
    [k, v] = SSTableParser.parse_string(@tsv_header_string <> line)
    {k, v}
  end

  defp plug([], _outfile) do
    nil
  end

  defp plug(batch, outfile) when is_list(batch) do
    case batch do
      [] ->
        nil

      many ->
        {the_lowest_key, the_lowest_value} =
          many
          |> Enum.map(fn {kv, _d} -> kv end)
          |> Sort.lowest()

        # output should be a TSV stream
        next_line_out = SSTableParser.dump_to_iodata([[the_lowest_key, the_lowest_value]])
        :file.write(outfile, next_line_out)

        next_round =
          many
          |> Enum.map(fn {kv_or_eof, d} ->
            case kv_or_eof do
              :eof -> {:eof, d}
              {k, _} when k == the_lowest_key -> {parse_tsv(:file.read_line(d)), d}
              higher -> {higher, d}
            end
          end)

        next_round |> Enum.filter(fn {kv_or_eof, _d} -> kv_or_eof != :eof end) |> plug(outfile)
    end
  end
end
