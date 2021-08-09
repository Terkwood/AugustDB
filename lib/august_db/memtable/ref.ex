defmodule Memtable.Ref do
  use Agent

  defstruct [:current, :flushing]

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def query(key) do
    case Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: _flushing} ->
           case Memtable.Dirty.query(current, key) do
             :none -> raise "query flushing"
             some -> some
           end
         end) do
      data ->
        {:value, data}

        # todo tombstones

        # todo none case
    end
  end
end
