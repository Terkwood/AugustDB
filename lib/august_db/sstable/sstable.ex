defmodule SSTable do
  import SSTable.Settings

  defstruct [:index, :table]

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
  Write a list of key/value pairs to binary SSTable file (<timestamp>.sst)
  Also write a sparse index of offsets (<timestamp>.idx)

  ## Example

  ```elixir
  tree = :gb_trees.enter("k3","uuu",:gb_trees.enter("k2","ww",:gb_trees.enter("k1","v",:gb_trees.empty())))
  SSTable.dump(tree)
  ```
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

    time = :erlang.system_time()
    sst_path = new_filename(time)

    {:ok, sst_out_file} = :file.open(sst_path, [:raw, :append])

    sparse_index = kvs |> write_sstable_and_index(sst_out_file)

    index_path = "#{time}.idx"
    File.write!(index_path, :erlang.term_to_binary(sparse_index))

    IO.puts("Dumped SSTable to #{sst_path}")

    {sst_path, sparse_index}
  end

  def new_filename(time_name \\ :erlang.system_time()) do
    "#{time_name}.sst"
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

  @tombstone tombstone()
  defp query(key, sst_file_or_timestamp) do
    file_timestamp = hd(String.split("#{sst_file_or_timestamp}", ".sst"))

    {:ok, index_bin} = File.read("#{file_timestamp}.idx")
    index = :erlang.binary_to_term(index_bin)

    nearest_offset =
      case find_nearest_offset(index, key) do
        nil -> :none
        offset -> offset
      end

    case nearest_offset do
      :none ->
        :none

      offset ->
        {:ok, sst} = :file.open("#{file_timestamp}.sst", [:read, :raw])

        out = keep_reading(key, sst, offset)

        :file.close(sst)

        out
    end
  end

  defp keep_reading(key, sst, offset) do
    case :file.pread(sst, offset, kv_length_bytes()) do
      {:ok, l} ->
        <<key_len::32, value_len::32>> = IO.iodata_to_binary(l)

        {:ok, key_bin} = :file.pread(sst, offset + kv_length_bytes(), key_len)
        next_key = :erlang.iolist_to_binary(key_bin)

        next_value_adjusted_len =
          case value_len do
            @tombstone -> 0
            n -> n
          end

        case next_key do
          n when n == key ->
            case value_len do
              @tombstone ->
                :tombstone

              vl ->
                {:ok, value_bin} = :file.pread(sst, offset + kv_length_bytes() + key_len, vl)
                :erlang.iolist_to_binary(value_bin)
            end

          n when n > key ->
            # we've gone too far!  the key isn't in this file
            :none

          _ignore ->
            keep_reading(
              key,
              sst,
              offset + kv_length_bytes() + key_len + next_value_adjusted_len
            )
        end

      :eof ->
        :none
    end
  end

  defp find_nearest_offset(index, key) do
    Enum.reduce_while(index, 0, fn {next_key, next_offset}, last_offset ->
      case next_key do
        n when n > key -> {:halt, last_offset}
        n when n == key -> {:halt, next_offset}
        _ -> {:cont, next_offset}
      end
    end)
  end

  defp write_sstable_and_index(pairs, device, acc \\ {0, [], nil})

  import SSTable.Write

  @index_chunk_size SSTable.Settings.index_chunk_size()
  defp write_sstable_and_index([{key, value} | rest], device, {byte_pos, idx, last_byte_pos}) do
    segment_size = write_kv(key, value, device)

    should_write_sparse_index_entry =
      case last_byte_pos do
        nil -> true
        lbp when lbp + @index_chunk_size < byte_pos -> true
        _too_soon -> false
      end

    next_len = byte_pos + segment_size

    next_acc =
      if should_write_sparse_index_entry do
        {next_len, [{key, byte_pos} | idx], byte_pos}
      else
        {next_len, idx, last_byte_pos}
      end

    write_sstable_and_index(rest, device, next_acc)
  end

  defp write_sstable_and_index([], _device, {_byte_pos, idx, _last_byte_pos}) do
    idx
  end
end
