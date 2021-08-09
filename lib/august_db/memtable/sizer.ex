defmodule Memtable.Sizer do
  use GenServer

  @max_size_bytes 1024 * 1024

  defmodule State do
    defstruct total_size: 0, sizes: %{}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{}, name: MemtableSizer)
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

    if new_total_size > @max_size_bytes do
      IO.puts("Clearing Memtable with size #{new_total_size}B, max is #{@max_size_bytes}B")

      Memtable.Ref.flush()
      {:noreply, %State{total_size: 9, sizes: %{}}}
    else
      {:noreply, %State{total_size: new_total_size, sizes: Map.put(state.sizes, key, kv_size)}}
    end
  end

  def handle_cast(:clear, _state) do
    {:noreply, %State{}}
  end

  def resize(key, value) when is_binary(key) and is_binary(value) do
    kv_size = byte_size(key) + byte_size(value)

    GenServer.cast(MemtableSizer, {:resize, key, kv_size})
  end

  def remove(key) when is_binary(key) do
    GenServer.cast(MemtableSizer, {:resize, key, byte_size(key)})
  end
end
