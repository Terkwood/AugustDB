defmodule SSTable.Compaction do
  import SSTable.Settings

  @moduledoc """
  SSTable Compaction
  """

  @doc """
  Run compaction on all SSTables, generating an SST and an IDX file
  """
  def run do
    old_sst_paths = Enum.sort(Path.wildcard("*.sst"))

    case merge(old_sst_paths) do
      :noop ->
        :noop

      new_sst_idx ->
        for p <- old_sst_paths do
          File.rm!(p)
          File.rm!(hd(String.split(p, ".sst")) <> ".idx")
        end

        new_sst_idx
    end
  end

  defmodule Periodic do
    use GenServer

    @compaction_period_minutes 1

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
      # Schedule work to be performed at some point
      schedule_work()
      {:ok, state}
    end

    def handle_info(:work, state) do
      case SSTable.Compaction.run() do
        {sst, _idx} -> IO.puts("Compacted #{sst}")
        _ -> nil
      end

      # Reschedule once more
      schedule_work()
      {:noreply, state}
    end

    defp schedule_work() do
      Process.send_after(self(), :work, @compaction_period_minutes * 60 * 1000)
    end
  end

  defmodule Sort do
    @spec lowest([{any, any}, ...]) :: {any, any}
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

        index = compare_and_write(many_kv_devices, output_sst, 0, [])

        Enum.map(many_devices, &:file.close(&1))
        :ok = :file.close(output_sst)

        index_binary = :erlang.term_to_binary(Map.new(index))
        index_path = hd(String.split(output_path, ".sst")) <> ".idx"
        File.write!(index_path, index_binary)

        {output_path, index_path}
    end
  end

  defp compare_and_write([], _outfile, _index_bytes, index) do
    index
  end

  import SSTable.Write

  defp compare_and_write(many_kv_devices_offsets, outfile, index_bytes, index)
       when is_list(many_kv_devices_offsets) do
    {the_lowest_key, the_lowest_value} =
      many_kv_devices_offsets
      |> Enum.map(fn {kv, _d, _offset} -> kv end)
      |> Sort.lowest()

    segment_size = write_kv(the_lowest_key, the_lowest_value, outfile)

    next_round =
      many_kv_devices_offsets
      |> Enum.map(fn {kv, d, offset} ->
        case kv do
          {k, _} when k == the_lowest_key -> read_one(d, offset)
          higher -> {higher, d, offset + segment_size}
        end
      end)

    next_round
    |> Enum.filter(fn tuple_or_eof ->
      case tuple_or_eof do
        :eof -> false
        _ -> true
      end
    end)
    |> compare_and_write(outfile, segment_size + index_bytes, [
      {the_lowest_key, index_bytes} | index
    ])
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
                {:ok, value_data} = :file.pread(device, offset + kv_length_bytes(), vl)
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
