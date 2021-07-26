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

  def update(key, value) do
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:value, value, System.monotonic_time()}, current),
        flushing: flushing
      }
    end)
  end

  def delete(key) do
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: flushing} ->
      %__MODULE__{
        current: :gb_trees.enter(key, {:tombstone, System.monotonic_time()}, current),
        flushing: flushing
      }
    end)
  end

  def flush() do
    flushing = Agent.get(__MODULE__, fn %__MODULE__{current: current, flushing: _} -> current end)

    IO.puts("to flush")
    IO.inspect(flushing)

    # Forget about whatever we were flushing before,
    # and move the current memtable into the flushing state.
    # Then clear the current memtable.
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: _} ->
      %__MODULE__{
        current: :gb_trees.empty(),
        flushing: current
      }
    end)

    sstable = SSTable.from(flushing)

    fname = "#{:erlang.system_time()}.sst"

    file_stream = File.stream!(fname)

    IO.inspect(sstable)

    {:ok, index_json} = Jason.encode(sstable.index)

    [index_json] |> Stream.into(file_stream) |> Stream.run()

    sstable.table |> Stream.into(file_stream) |> Stream.run()

    # Finished.  Clear the flushing table state.
    Agent.update(__MODULE__, fn %__MODULE__{current: current, flushing: _} ->
      %__MODULE__{
        current: current,
        flushing: :gb_trees.empty()
      }
    end)
  end
end
