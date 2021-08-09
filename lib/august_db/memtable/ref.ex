defmodule Memtable.Ref do
  use Agent

  defstruct [:current, :flushing]

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def query(key) do
    Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
      case Memtable.Dirty.query(current, key) do
        {:none, _} -> Memtable.Dirty.query(flushing, key)
        some -> some
      end
    end)
  end

  def update(key, value) when is_binary(key) and is_binary(value) do
    Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: _flushing} ->
      Memtable.Dirty.update(current, key, value)
    end)

    Memtable.Sizer.resize(key, value)

    :ok
  end

  def delete(key) when is_binary(key) do
    Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: _flushing} ->
      Memtable.Dirty.delete(current, key)
    end)

    Memtable.Sizer.remove(key)

    :ok
  end
end
