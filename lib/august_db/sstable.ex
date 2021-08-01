defmodule SSTable do
  defstruct [:index, :table]

  @doc """
  Dump a list of key/value pairs to binary, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index
      %{
        "k1" => 4,
        "k2" => 9,
        "k3" => 15,
      }

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.table
      ???
  """
  def dump(keyvals) when is_list(keyvals) do
    kv_bins = keyvals |> to_binary

    raise "todo"
    raise "the values can be tombstone atoms"
  end

  def from(memtable) do
    maybe_kvs =
      for entry <- :gb_trees.to_list(memtable) do
        case entry do
          {key, {:value, value, _time}} -> [key, value]
          {key, {:tombstone, _time}} -> [key, :tombstone]
          _ -> nil
        end
      end

    kvs = Enum.filter(maybe_kvs, &(&1 != nil))

    dump(kvs)
  end

  defp to_binary(kvts) do
    raise "todo"
  end
end
