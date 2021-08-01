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
    kv_bin_idxs = keyvals |> to_binary_idx

    IO.inspect(kv_bin_idxs)
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

  @tombstone -1
  defp to_binary_idx([{key, value} | rest], acc \\ {0, <<>>, %{}}) do
    ks = byte_size(key)

    segment =
      case value do
        :tombstone ->
          <<ks::64>> <> <<@tombstone::64>> <> key

        bin when is_binary(bin) ->
          vs = byte_size(bin)
          <<ks::64, vs::64>> <> key <> bin
      end

    {al, ab, idx} = acc
    next_len = al + byte_size(segment)

    to_binary_idx(rest, {next_len, ab <> segment, Map.put(idx, key, al)})
  end

  defp to_binary_idx([], {_byte_pos, bin, idx}) do
    {bin, idx}
  end
end
