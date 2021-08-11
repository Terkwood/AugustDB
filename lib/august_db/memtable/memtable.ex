defmodule Memtable do
  use Agent

  defstruct current: :gb_trees.empty(), flushing: :gb_trees.empty()

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  def query(key) do
    case Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
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

  def update(key, value) when is_binary(key) and is_binary(value) do
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:value, value, System.monotonic_time()}, current),
        flushing: flushing
      }
    end)

    Memtable.Sizer.resize(key, value)

    :ok
  end

  def delete(key) do
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:tombstone, System.monotonic_time()}, current),
        flushing: flushing
      }
    end)

    Memtable.Sizer.remove(key)

    :ok
  end

  def flush() do
    flushing =
      Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: pend} ->
        if :gb_trees.is_empty(pend) and !:gb_trees.is_empty(current) do
          {:proceed, current}
        else
          :stop
        end
      end)

    case flushing do
      # flush is pending, don't start multiple
      :stop ->
        nil

      {:proceed, old_tree} ->
        # Forget about whatever we were flushing before,
        # and move the current memtable into the flushing state.
        # Then clear the current memtable.
        Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: _} ->
          %__MODULE__{
            current: :gb_trees.empty(),
            flushing: current
          }
        end)

        # Start a new commit log.
        {:old_path, old_path} = CommitLog.swap()

        # Write the current memtable to disk in a binary format
        {flushed_sst_path, sparse_index} = SSTable.dump(old_tree)
        # ⚡ Keep a copy of the index in memory ⚡
        SSTable.Index.remember(flushed_sst_path, sparse_index)

        # Create a cuckoo filter in memory for this table
        CuckooFilter.remember(flushed_sst_path, :gb_trees.keys(old_tree))

        # Finished.  Clear the flushing table state.
        Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: _} ->
          %__MODULE__{
            current: current,
            flushing: :gb_trees.empty()
          }
        end)

        CommitLog.delete(old_path)
    end
  end
end
