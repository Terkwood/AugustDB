defmodule Memtable do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, fn tree -> :gb_trees.get(key, tree) end)
  end

  def update(key, value) do
    Agent.update(__MODULE__, fn tree ->
      :gb_trees.update(key, {:value, value, System.monotonic_time()}, tree)
    end)
  end

  def delete(key) do
    Agent.update(__MODULE__, fn tree ->
      :gb_trees.update(key, {:tombstone, System.monotonic_time()}, tree)
    end)
  end
end
