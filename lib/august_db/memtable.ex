defmodule Memtable do
  use Agent

  defstruct current: :gb_trees.empty(), flushing: :gb_trees.empty()

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def query(key) do
    case Agent.get(__MODULE__, fn %Memtable{current: current, flushing: flushing} ->
           case :gb_trees.lookup(key, current) do
             :none -> :gb_trees.lookup(key, flushing)
             some -> some
           end
         end) do
      {:value, {:value, data, time}} ->
        {:value, data, time}

      {:value, {:tombstone, time}} ->
        {:tombstone, time}

      :none ->
        :none
    end
  end

  def update(key, value) do
    IO.inspect(key)
    IO.inspect(value)

    Agent.update(__MODULE__, fn mt ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:value, value, System.monotonic_time()}, mt.current),
        flushing: mt.flushing
      }
    end)
  end

  def delete(key) do
    Agent.update(__MODULE__, fn mt ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:tombstone, System.monotonic_time()}, mt.current),
        flushing: mt.flushing
      }
    end)
  end

  def flush() do
    raise "todo"
  end
end
