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
    for idx_p <- Path.wildcard("*.idx") do
      sparse_index = :erlang.binary_to_term(File.read!(idx_p))
      sst_filename = "#{hd(String.split(idx_p, ".idx"))}.sst"
      remember(sst_filename, sparse_index)
    end
  end

  @doc """
  Scan the filesystem and figure out which indices no longer exist,
  then remove them from agent memory.
  """
  def evict do
    file_system_ssts = MapSet.new(Path.wildcard("*.sst"))

    agent_ssts =
      MapSet.new(
        Agent.get(
          __MODULE__,
          &Map.keys(&1)
        )
      )

    Agent.update(__MODULE__, fn map ->
      Map.drop(map, MapSet.to_list(MapSet.difference(agent_ssts, file_system_ssts)))
    end)
  end
end
