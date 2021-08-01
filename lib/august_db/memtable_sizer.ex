defmodule Memtable.Sizer do
  use GenServer

  @max_size_bytes 64

  defmodule State do
    defstruct total_size: 0, sizes: %{}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{}, name: MemtableSizer)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:resize, key, kv_size}, _from, state) do
    old_kv_size =
      case Map.get(state.sizes, key) do
        nil -> 0
        n -> n
      end

    kv_size_diff = kv_size - old_kv_size

    new_total_size = state.total_size + kv_size_diff

    {:reply, new_total_size,
     %State{total_size: new_total_size, sizes: Map.put(state.sizes, key, kv_size)}}
  end

  def handle_cast(:clear, _state) do
    {:noreply, %State{}}
  end

  def resize(key, value) when is_binary(key) and is_binary(value) do
    kv_size = byte_size(key) + byte_size(value)

    update(key, kv_size)
  end

  def remove(key) when is_binary(key) do
    update(key, byte_size(key))
  end

  defp update(key, kv_size) do
    IO.puts("hey")
    new_total_size = GenServer.call(MemtableSizer, {:resize, key, kv_size})
    IO.puts("ho")

    if new_total_size > @max_size_bytes do
      IO.puts("... clearing memtable ..")
      Memtable.flush()
      __MODULE__.clear()
    end
  end

  def clear() do
    GenServer.cast(MemtableSizer, :clear)
  end
end
