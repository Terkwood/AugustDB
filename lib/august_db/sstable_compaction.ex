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
      case Compaction.run() do
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

  # def merge([]) do
  #  :noop
  # end

  # defp merge([_single_path]) do
  #  :noop
  # end

  @tombstone tombstone()
  defp merge(many_paths) when is_list(many_paths) do
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
        case :file.pread(device, offset, kv_length_bytes()) do
          :eof ->
            {:eof, device}

          {:ok, l} ->
            <<key_len::32, value_len::32>> = IO.iodata_to_binary(l)

            case :file.pread(device, offset + kv_length_bytes(), key_len) do
              {:ok, key_data} ->
                key = IO.iodata_to_binary(key_data)

                case value_len do
                  @tombstone ->
                    {{key, :tombstone}, device}

                  vl ->
                    {:ok, value_data} = :file.pread(device, offset + kv_length_bytes(), vl)
                    value = IO.iodata_to_binary(value_data)
                    {{key, value}, device}
                end

              :eof ->
                {:eof, device}
            end
        end
      end)
      |> Enum.filter(fn maybe_eof ->
        case maybe_eof do
          {:eof, _device} -> false
          _ -> true
        end
      end)

    raise "todo check zero arg (index_bytes)"
    index = plug(many_kv_devices, output_sst, 0, [])

    Enum.map(many_devices, :ok = &:file.close(&1))
    :ok = :file.close(output_sst)

    index_binary = :erlang.term_to_binary(Map.new(index))
    index_path = hd(String.split(output_path, ".sst")) <> ".idx"
    File.write!(index_path, index_binary)

    {output_path, index_path}
  end

  defp plug(many_kv_devices, outfile, index_bytes, index) when is_list(many_kv_devices) do
    raise "todo"
  end
end
