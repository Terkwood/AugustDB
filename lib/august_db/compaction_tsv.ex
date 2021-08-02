# defmodule Compaction do
#   @moduledoc """
#   SSTable Compaction
#   """

#   @doc """
#   Run compaction on all SSTables, generating an SST and an IDX file
#   """
#   def run do
#     old_sst_paths = Enum.sort(Path.wildcard("*.sst"))

#     case merge(old_sst_paths) do
#       :noop ->
#         :noop

#       new_sst_idx ->
#         for p <- old_sst_paths do
#           File.rm!(p)
#           File.rm!(hd(String.split(p, ".sst")) <> ".idx")
#         end

#         new_sst_idx
#     end
#   end

#   defmodule Sort do
#     @spec lowest([{any, any}, ...]) :: {any, any}
#     def lowest([{k, v} | newer]) do
#       lowest([{k, v} | newer], {k, v})
#     end

#     def lowest([], {acc_k, acc_v}) do
#       {acc_k, acc_v}
#     end

#     def lowest([{next_k, next_v} | newer], {acc_k, acc_v}) do
#       if next_k <= acc_k do
#         lowest(newer, {next_k, next_v})
#       else
#         lowest(newer, {acc_k, acc_v})
#       end
#     end
#   end

#   defmodule Periodic do
#     use GenServer

#     @compaction_period_minutes 1

#     def start_link(_opts) do
#       GenServer.start_link(__MODULE__, %{})
#     end

#     def init(state) do
#       # Schedule work to be performed at some point
#       schedule_work()
#       {:ok, state}
#     end

#     def handle_info(:work, state) do
#       case Compaction.run() do
#         {sst, _idx} -> IO.puts("Compacted #{sst}")
#         _ -> nil
#       end

#       # Reschedule once more
#       schedule_work()
#       {:noreply, state}
#     end

#     defp schedule_work() do
#       Process.send_after(self(), :work, @compaction_period_minutes * 60 * 1000)
#     end
#   end

#   defp merge([]) do
#     :noop
#   end

#   defp merge([_single_path]) do
#     :noop
#   end

#   @tsv_header_string TSV.header_string()
#   defp merge(many_paths) when is_list(many_paths) do
#     time_name = :erlang.system_time()
#     output_path = "#{time_name}.sst"

#     many_devices =
#       Enum.map(many_paths, fn p ->
#         {:ok, f} = :file.open(p, [:read, :binary, {:read_ahead, 100_000}])
#         f
#       end)

#     {:ok, output_sst} = :file.open(output_path, [:append])

#     # write header
#     :ok = :file.write(output_sst, @tsv_header_string)

#     many_kv_devices =
#       many_devices
#       |> Enum.map(fn d ->
#         # skip the header line
#         :file.read_line(d)
#         kv_or_eof = parse_tsv(:file.read_line(d))
#         {kv_or_eof, d}
#       end)
#       |> Enum.filter(fn {kv_or_eof, _d} -> kv_or_eof != :eof end)

#     index = plug(many_kv_devices, output_sst, byte_size(@tsv_header_string), [])

#     Enum.map(many_devices, &:file.close(&1))
#     :file.close(output_sst)

#     index_binary = :erlang.term_to_binary(Map.new(index))
#     index_path = "#{time_name}.idx"
#     File.write!(index_path, index_binary)

#     # return the path to the output file, and the path to the index file
#     {output_path, index_path}
#   end

#   def parse_tsv(:eof) do
#     :eof
#   end

#   @tsv_header_string TSV.header_string()
#   def parse_tsv({:ok, line}) do
#     [[k, v]] = SSTableParser.parse_string(@tsv_header_string <> line)
#     {k, v}
#   end

#   defp plug([], _outfile, _index_bytes, index) do
#     index
#   end

#   defp plug(many, outfile, index_bytes, index) when is_list(many) do
#     {the_lowest_key, the_lowest_value} =
#       many
#       |> Enum.map(fn {kv, _d} -> kv end)
#       |> Sort.lowest()

#     # output should be a TSV stream
#     next_line_out = SSTableParser.dump_to_iodata([[the_lowest_key, the_lowest_value]])
#     :file.write(outfile, next_line_out)

#     next_round =
#       many
#       |> Enum.map(fn {kv_or_eof, d} ->
#         case kv_or_eof do
#           :eof -> {:eof, d}
#           {k, _} when k == the_lowest_key -> {parse_tsv(:file.read_line(d)), d}
#           higher -> {higher, d}
#         end
#       end)

#     next_round
#     |> Enum.filter(fn {kv_or_eof, _d} -> kv_or_eof != :eof end)
#     |> plug(
#       outfile,
#       byte_size(IO.iodata_to_binary(next_line_out)) + index_bytes,
#       [{the_lowest_key, index_bytes} | index]
#     )
#   end
# end
