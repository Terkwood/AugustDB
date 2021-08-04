defmodule SSTable.Compaction do
  import SSTable.Settings

  @moduledoc """
  SSTable Compaction
  """

  @doc """
  Run compaction on all SSTables, generating a Sorted String Table file
  (.sst) and an erlang binary representation of its index (key to byte
  offset) as a `.idx` file.  The index is sparse, having only one entry
  per `SSTable.Settings.index_chunk_size` bytes.
  """
  def run do
    old_sst_paths = Enum.sort(Path.wildcard("*.sst"))

    case merge(old_sst_paths) do
      :noop ->
        :noop

      {sst_filename, sparse_index} ->
        for p <- old_sst_paths do
          File.rm!(p)
          File.rm!(hd(String.split(p, ".sst")) <> ".idx")
        end

        # save the new index into main memory
        SSTable.Index.remember(sst_filename, sparse_index)

        # evict all the defunct indices from main memory
        SSTable.Index.evict()

        {sst_filename, sparse_index}
    end
  end

  defmodule Periodic do
    use GenServer

    @compaction_period_seconds 60

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
      schedule_work()
      {:ok, state}
    end

    def handle_info(:work, state) do
      case SSTable.Compaction.run() do
        {sst, _idx} -> IO.puts("Compacted #{sst}")
        _ -> nil
      end

      # Do it again
      schedule_work()
      {:noreply, state}
    end

    defp schedule_work() do
      Process.send_after(self(), :work, @compaction_period_seconds * 1000)
    end
  end

  defmodule Sort do
    @doc """
    Finds the lowest _and_ most recent key across multiple file
    segments.
    """
    @spec lowest_most_recent([{any, any}, ...]) :: {any, any}
    def lowest_most_recent([{k, v} | newer]) do
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

  defmodule IndexAcc do
    defstruct index: [],
              current_offset: 0,
              last_offset: nil
  end

  @tombstone tombstone()
  defp merge(paths) when is_list(paths) do
    case paths do
      [] ->
        :noop

      [_one] ->
        :noop

      many_paths ->
        output_path = SSTable.new_filename()

        many_devices =
          Enum.map(many_paths, fn p ->
            {:ok, f} = :file.open(p, [:read, :raw])
            f
          end)

        {:ok, output_sst} = :file.open(output_path, [:raw, :append])

        many_kv_devices =
          many_devices
          |> Enum.map(&{&1, 0})
          |> Enum.map(fn {device, offset} ->
            read_one(device, offset)
          end)
          |> Enum.filter(fn maybe_eof ->
            case maybe_eof do
              :eof -> false
              _ -> true
            end
          end)

        index = compare_and_write(many_kv_devices, output_sst, %IndexAcc{})

        Enum.map(many_devices, &:file.close(&1))
        :ok = :file.close(output_sst)

        index_binary = :erlang.term_to_binary(index)
        index_path = hd(String.split(output_path, ".sst")) <> ".idx"
        File.write!(index_path, index_binary)

        {output_path, index}
    end
  end

  defp compare_and_write([], _outfile, %IndexAcc{index: index, last_offset: _, current_offset: _}) do
    index
  end

  import SSTable.Write
  @index_chunk_size SSTable.Settings.index_chunk_size()
  defp compare_and_write(many_kv_devices_offsets, outfile, %IndexAcc{
         index: index,
         current_offset: index_bytes,
         last_offset: last_offset
       })
       when is_list(many_kv_devices_offsets) do
    {the_lowest_key, the_lowest_value} =
      many_kv_devices_offsets
      |> Enum.map(fn {kv, _d, _offset} -> kv end)
      |> Sort.lowest_most_recent()

    segment_size = write_kv(the_lowest_key, the_lowest_value, outfile)

    next_round =
      many_kv_devices_offsets
      |> Enum.map(fn {kv, d, offset} ->
        case kv do
          {k, _} when k == the_lowest_key ->
            read_one(d, offset)

          higher ->
            {higher, d, offset}
        end
      end)

    should_write_sparse_index_entry =
      case last_offset do
        nil -> true
        lbp when lbp + @index_chunk_size < index_bytes -> true
        _too_soon -> false
      end

    next_acc =
      if should_write_sparse_index_entry do
        %IndexAcc{
          current_offset: segment_size + index_bytes,
          index: [
            {the_lowest_key, index_bytes} | index
          ],
          last_offset: index_bytes
        }
      else
        %IndexAcc{
          current_offset: segment_size + index_bytes,
          index: index,
          last_offset: last_offset
        }
      end

    next_round
    |> Enum.filter(fn tuple_or_eof ->
      case tuple_or_eof do
        :eof -> false
        _ -> true
      end
    end)
    |> compare_and_write(outfile, next_acc)
  end

  defp read_one(device, offset) do
    case :file.pread(device, offset, kv_length_bytes()) do
      :eof ->
        :eof

      {:ok, l} ->
        <<key_len::32, value_len::32>> = IO.iodata_to_binary(l)

        case :file.pread(device, offset + kv_length_bytes(), key_len) do
          {:ok, key_data} ->
            key = IO.iodata_to_binary(key_data)

            case value_len do
              @tombstone ->
                next_offset = offset + kv_length_bytes() + key_len
                {{key, :tombstone}, device, next_offset}

              vl ->
                {:ok, value_data} = :file.pread(device, offset + kv_length_bytes() + key_len, vl)
                value = IO.iodata_to_binary(value_data)
                next_offset = offset + kv_length_bytes() + key_len + vl
                {{key, value}, device, next_offset}
            end

          :eof ->
            :eof
        end
    end
  end
end
