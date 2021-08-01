defmodule SSTable do
  @doc """
  Dump a list of key/value pairs to an IO-ready binary stream, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index
      %{
        "k1" => 4,
        "k2" => 9,
        "k3" => 15,
      }

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> raise "todo"
      iex> IO.iodata_to_binary(Enum.to_list(them.table))
      ???
  """
  def dump(keyvals) when is_list(keyvals) do
    raise "todo"
  end

  def from(memtable) do
    raise "todo"
  end
end
