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

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: CuckooFilterAgent)
  end

  def init(state) do
    {:ok, state}
  end

  def write(sst_path, filter) do
    Agent.update(__MODULE__, &Map.put(&1, sst_path, filter))
  end

  def delete(sst_path) do
    Agent.update(__MODULE__, &Map.drop(&1, [sst_path]))
  end

  def initialize(sst_path, memtable_keys) do
    filter = :cuckoo_filter.new(max(length(memtable_keys), 1))

    for key <- memtable_keys do
      :cuckoo_filter.add(filter, key)
    end

    write(sst_path, filter)
  end
end
