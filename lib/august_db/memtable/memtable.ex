defmodule Memtable do
  def query(key) do
    case(
      case Memtable.Dirty.query(key) do
        {:none, _} -> Memtable.Dirty.query(key)
        some -> some
      end
    ) do
      # hide the empty string that we used in rust
      {:tombstone, ""} -> :tombstone
      {:none, ""} -> :none
      value -> value
    end
  end

  def update(key, value) when is_binary(key) and is_binary(value) do
    :ok = Memtable.Dirty.update(key, value)

    Memtable.Sizer.resize(key, value)

    :ok
  end

  def delete(key) when is_binary(key) do
    :ok = Memtable.Dirty.delete(key)

    Memtable.Sizer.remove(key)

    :ok
  end

  def flush() do
    case Memtable.Dirty.prepare_flush() do
      # flush is pending -- do nothing
      {:stop, _} ->
        nil

      {:proceed, old_tree} ->
        # Start a new commit log
        CommitLog.new()

        # Write the current memtable to disk in a binary format
        {flushed_sst_path, sparse_index} = SSTable.dump(old_tree)
        # ⚡ Keep a copy of the index in memory ⚡
        SSTable.Index.remember(flushed_sst_path, sparse_index)

        # Create a cuckoo filter in memory for this table
        CuckooFilter.remember(flushed_sst_path, old_tree |> Enum.map(fn {k, _} -> k end))

        # Finished.  Clear the flushing table state.
        Memtable.Dirty.finalize_flush()
    end
  end

  @doc """
  Called by `CommitLog.replay()`
  """
  def clear() do
    Memtable.Dirty.clear()
  end
end

defmodule Memtable.Dead do
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
end
