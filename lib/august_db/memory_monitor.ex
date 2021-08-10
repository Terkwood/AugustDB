defmodule MemoryMonitor do
  use GenServer

  @period_seconds 10

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, state) do
    for {type, size} <- :erlang.memory() do
      padded = String.pad_leading("#{type}", 10, " ")
      IO.puts("#{padded}\t#{size}")
    end

    # Do it again
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, @period_seconds * 1000)
  end
end
