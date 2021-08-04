defmodule SSTable.Index do
  use Agent

  @moduledoc """
  This agent keeps all sparse SSTable indices in memory.
  """

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end, name: __MODULE__)
  end

  @doc """
  Retrieve the sparse index for a given SSTable.
  """
  def get(sst_filename) do
    raise "todo"
  end

  @doc """
  Saves a sparse index into memory.  It can be queried by its associated SSTable filename.
  """
  def put(sst_filename, sparse_index) do
    raise "todo"
  end

  @doc """
  Load all sparse indices from disk and save them into main memory.
  """
  def load_all do
  end
end
