defmodule Memtable.Sizer do
  use GenServer

  defmodule State do
    defstruct total_size: 0, kv_size: %{}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{})
  end

  def init(state) do
    {:ok, state}
  end
end
