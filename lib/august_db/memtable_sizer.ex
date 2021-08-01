defmodule Memtable.Sizer do
  use GenServer

  defmodule State do
    defstruct total_size: 0, sizes: %{}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:resize, key, kv_size}, state) do
    old_kv_size =
      case Map.get(state.sizes, key) do
        nil -> 0
        n -> n
      end

    kv_size_diff = kv_size - old_kv_size

    new_total_size = state.total_size + kv_size_diff

    {:noreply, %State{total_size: new_total_size, sizes: Map.put(state.sizes, key, kv_size)}}
  end
end
