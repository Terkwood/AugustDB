defmodule CuckooFilter do
  use Agent

  @moduledoc """
  Using SSTables, it takes a long time to determine that a certain
  record does not exist. In the case where there is neither a value
  nor a tombstone associated with a key, you need to read through all
  SSTables before you can return a negative result.

  You can use a bloom or cuckoo filter to speed up queries for kv pairs
  which don't exist. These probabilistic data structures allow you to
  (mostly) determine set membership.

  When the set membership test returns false, you can rely on the result.
  The K/V pair definitely does not exist.

  When the set membership test returns true, there's a possibility that
  it's a false positive -- it may not be in the given table.

  ## Structure of this module

  - Agent for in-memory storage
  - Client API to be called from Memtable.flush() and Compaction.run()
  """

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def remember(sst_path, memtable_keys) do
    filter = :cuckoo_filter.new(max(length(memtable_keys), 1))

    for key <- memtable_keys do
      :cuckoo_filter.add(filter, key)
    end

    Agent.update(__MODULE__, &Map.put(&1, sst_path, filter))
  end

  @doc """
  Return paths to those SSTables where we can be sure that the key does
  not exist.
  """
  def eliminate(key) do
    IO.inspect(
      MapSet.new(
        Agent.get(__MODULE__, fn map ->
          for {sst_path, filter} <- map, !:cuckoo_filter.contains(filter, key) do
            sst_path
          end
        end)
      )
    )
  end

  def forget(old_sst_paths) do
    Agent.update(__MODULE__, &Map.drop(&1, old_sst_paths))
  end
end
