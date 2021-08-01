defmodule SSTable.Compaction do
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

  defp merge(many_paths) when is_list(many_paths) do
    output_path = SSTable.new_filename()

    many_devices =
      Enum.map(many_paths, fn p ->
        {:ok, f} = :file.open(p, [:read, :raw])
        f
      end)

    {:ok, output_sst} = :file.open(output_path, [:raw, :append])

    raise "todo"
  end
end
