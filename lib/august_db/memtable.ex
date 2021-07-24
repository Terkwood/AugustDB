defmodule Memtable do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def query(key) do
    case Agent.get(__MODULE__, fn tree -> :gb_trees.lookup(key, tree) end) do
      {:value, {:value, data, time}} ->
        {:value, data, time}

      {:value, {:tombstone, time}} ->
        {:tombstone, time}

      :none ->
        :none
    end
  end

  def update(key, value) do
    Agent.update(__MODULE__, fn tree ->
      :gb_trees.enter(key, {:value, value, System.monotonic_time()}, tree)
    end)
  end

  def delete(key) do
    Agent.update(__MODULE__, fn tree ->
      :gb_trees.enter(key, {:tombstone, System.monotonic_time()}, tree)
    end)
  end
end
