defmodule SSTable do
  defstruct [:index, :table]

  @tombstone 4_294_967_296

  @doc """
  Query all SSTable files using their associated index file and a key,
  returning a value if present. Filters tombstone entries.

  There must be an associated `<timestamp>.idx` file present for each SSTable,
  or the private query function will fail.

  This function returns `:tombstone` in the case of deleted entries.

  ## Examples

  Basic query

  ```elixir
  SSTable.query_all("a")
  ```

  Combined with Memtable

  ```elixir
  Memtable.update("bar","BAZ"); Memtable.delete("foo"); Memtable.flush()
  :ok
  SSTable.query_all("bar")
  "BAZ"
  SSTable.query_all("foo")
  :tombstone
  SSTable.query_all("a")
  :none
  ```
  """
  def query_all(key) do
    sst_files = Path.wildcard("*.sst") |> Enum.sort() |> Enum.reverse()
    query_all(key, sst_files)
  end

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

    time_name = "#{:erlang.system_time()}"

    table_fname = "#{time_name}.sst"

    {:ok, sst_out_file} = :file.open(table_fname, [:raw, :append])

    idx = kvs |> write_binary_idx(sst_out_file)

    index_path = "#{time_name}.idx"
    File.write!(index_path, :erlang.term_to_binary(idx))

    IO.puts("Dumped SSTable to #{table_fname}")
  end

  defp query_all(_key, []) do
    :none
  end

  defp query_all(key, [sst_file | rest]) do
    case query(key, sst_file) do
      :none -> query_all(key, rest)
      :tombstone -> :tombstone
      value -> value
    end
  end

  @length_bytes 8
  defp query(key, sst_file_or_timestamp) do
    file_timestamp = hd(String.split("#{sst_file_or_timestamp}", ".sst"))

    {:ok, index_bin} = File.read("#{file_timestamp}.idx")
    index = :erlang.binary_to_term(index_bin)

    maybe_offset =
      case Map.get(index, key) do
        nil -> :none
        offset -> offset
      end

    case maybe_offset do
      :none ->
        :none

      offset ->
        {:ok, sst} = :file.open("#{file_timestamp}.sst", [:read, :raw])

        out =
          case :file.pread(sst, offset, @length_bytes) do
            {:ok, l} ->
              <<key_len::32, value_len::32>> = IO.iodata_to_binary(l)

              IO.inspect({key_len, value_len})

              case value_len do
                @tombstone ->
                  :tombstone

                vl ->
                  {:ok, value_bin} = :file.pread(sst, offset + @length_bytes + key_len, vl)
                  :erlang.iolist_to_binary(value_bin)
              end

            :eof ->
              :none
          end

        :file.close(sst)

        out
    end
  end

  defp write_binary_idx(pairs, device, acc \\ {0, %{}})

  defp write_binary_idx([{key, value} | rest], device, acc) do
    ks = byte_size(key)

    segment_size =
      case value do
        :tombstone ->
          kl = <<ks::32>>
          vl = <<@tombstone::32>>
          :ok = :file.write(device, kl)
          :ok = :file.write(device, vl)
          :ok = :file.write(device, key)
          byte_size(kl) + byte_size(vl) + byte_size(key)

        bin when is_binary(bin) ->
          vs = byte_size(bin)
          kvl = <<ks::32, vs::32>>
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
