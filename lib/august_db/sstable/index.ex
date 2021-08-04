defmodule SSTable.Index do
  use Agent

  @moduledoc """
  ⚡ This agent keeps all sparse SSTable indices in memory. ⚡
  """

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  @doc """
  Retrieve the sparse index for a given SSTable.
  """
  def fetch(sst_filename) do
    Agent.get(__MODULE__, fn map ->
      case Map.get(map, sst_filename) do
        nil -> nil
        index -> index
      end
    end)
  end

  @doc """
  Saves a sparse index into memory.  It can be queried by its associated
  SSTable filename.
  """
  def remember(sst_filename, sparse_index) do
    Agent.update(__MODULE__, fn map -> Map.put(map, sst_filename, sparse_index) end)
  end

  @doc """
  Load all sparse indices from disk and save them into main memory.
  """
  def load_all do
    raise "todo"
  end

  @doc """
  Scan the filesystem and figure out which indices no longer exist,
  then remove them from agent memory.
  """
  def evict do
    raise "todo"
  end
end
