defmodule SSTable do
  defstruct [:index, :table]

  @doc """
  Write a list of key/value pairs to binary SSTable file
  Also write an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index
      %{
        "k1" => 4,
        "k2" => 9,
        "k3" => 15,
      }

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
  """
  def dump(gb_tree) do
    maybe_kvs =
      for entry <- :gb_trees.to_list(gb_tree) do
        case entry do
          {key, {:value, value, _time}} -> {key, value}
          {key, {:tombstone, _time}} -> {key, :tombstone}
          _ -> nil
        end
      end

    kvs = Enum.filter(maybe_kvs, &(&1 != nil))

    IO.inspect(kvs)

    time_name = "#{:erlang.system_time()}"

    table_fname = "#{time_name}.sst"

    {:ok, sst_out_file} = :file.open(table_fname, [:raw, :append])

    idx = kvs |> write_binary_idx(sst_out_file)
    IO.inspect(idx)

    index_path = "#{time_name}.idx"
    File.write!(index_path, :erlang.term_to_binary(idx))
  end

  defp write_binary_idx(pairs, device, acc \\ {0, %{}})
  @tombstone -1
  defp write_binary_idx([{key, value} | rest], device, acc) do
    ks = byte_size(key)

    segment_size =
      case value do
        :tombstone ->
          kl = <<ks::64>>
          vl = <<@tombstone::64>>
          :ok = :file.write(device, kl)
          :ok = :file.write(device, vl)
          :ok = :file.write(device, key)
          byte_size(kl) + byte_size(vl) + byte_size(key)

        bin when is_binary(bin) ->
          vs = byte_size(bin)
          kvl = <<ks::64, vs::64>>
          :ok = :file.write(device, kvl)
          :ok = :file.write(device, key)
          :ok = :file.write(device, bin)
          byte_size(kvl) + byte_size(key) + byte_size(bin)
      end

    {al, idx} = acc
    next_len = al + segment_size

    write_binary_idx(rest, device, {next_len, Map.put(idx, key, al)})
  end

  defp write_binary_idx([], _device, {_byte_pos, idx}) do
    idx
  end
end
