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
