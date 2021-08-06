defmodule SSTable do
  @moduledoc """
  # Specification of Sorted String Table files

  A Sorted String Table contains zero or more _gzipped key/value chunks_.

  ## GZipped key/value chunks

  A _gzip key/value chunk_ follows this binary specification:

  1. Four bytes: length of the gzipped chunk
  2. Variable length: gzipped chunk of key/value pairs, with tombstones.

  ## Unzipped key/value chunks

  Once unzipped, each key/value chunk contains zero or more key/value records.
  Each record describes its own length. Some keys may point to
  tombstones.

  ### Value records

  1. Four bytes: Length of key
  2. Four bytes: Length of value
  3. Variable length: Raw key, not escaped
  4. Variable length: Raw value, not escaped

  ### Tombstone records

  1. Four bytes: Length of key in bytes
  2. Four bytes: `2^32 - 1` to indicate tombstone
  3. Variable length: Raw key, not escaped
  """
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

    {payload, sparse_index} = SSTable.Zip.zip(kvs)

    time = :erlang.system_time()
    sst_path = new_filename(time)
    idx_path = "#{time}.idx"

    File.write!(sst_path, payload)
    File.write!(idx_path, :erlang.term_to_binary(sparse_index))

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
  @gzip_length_bytes SSTable.Settings.gzip_length_bytes()
  defp query(key, sst_filename) when is_binary(sst_filename) do
    index = SSTable.Index.fetch(sst_filename)

    nearest_offset =
      case find_nearest_offset(index, key) do
        nil -> :none
        offset -> offset
      end

    case nearest_offset do
      :none ->
        :none

      offset ->
        {:ok, sst} = :file.open(sst_filename, [:read, :raw])

        {:ok, iod} = :file.pread(sst, offset, @gzip_length_bytes)
        <<gzipped_chunk_size::@gzip_length_bytes*8>> = IO.iodata_to_binary(iod)

        {:ok, gzipped_chunk} = :file.pread(sst, offset + @gzip_length_bytes, gzipped_chunk_size)

        :file.close(sst)

        chunk = :zlib.gunzip(IO.iodata_to_binary(gzipped_chunk))

        keep_reading(key, chunk)
    end
  end

  @tombstone SSTable.Settings.tombstone()
  defp keep_reading(key, chunk) do
    case chunk do
      "" ->
        :none

      <<next_key_len::32, next_value_len_tombstone::32, r::binary>> ->
        <<next_key::binary-size(next_key_len), s::binary>> = r

        {value_or_tombstone, next_vt_len} =
          case next_value_len_tombstone do
            t when t == @tombstone ->
              {:tombstone, 0}

            vl ->
              <<next_value::binary-size(vl), _::binary>> = IO.iodata_to_binary(s)
              {next_value, vl}
          end

        if next_key == key do
          value_or_tombstone
        else
          case next_vt_len do
            0 ->
              # no need to skip tombstone
              keep_reading(key, s)

            n ->
              # skip the next value, then keep reading
              <<_::binary-size(n), u::binary>> = s
              keep_reading(key, u)
          end
        end
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

  # defp write_sstable_and_index(pairs, device, acc \\ {0, [], nil})

  # import SSTable.Write

  # @index_chunk_size SSTable.Settings.index_chunk_size()
  # defp write_sstable_and_index([{key, value} | rest], device, {byte_pos, idx, last_byte_pos}) do
  #   segment_size = write_kv(key, value, device)

  #   should_write_sparse_index_entry =
  #     case last_byte_pos do
  #       nil -> true
  #       lbp when lbp + @index_chunk_size < byte_pos -> true
  #       _too_soon -> false
  #     end

  #   next_len = byte_pos + segment_size

  #   next_acc =
  #     if should_write_sparse_index_entry do
  #       {next_len, [{key, byte_pos} | idx], byte_pos}
  #     else
  #       {next_len, idx, last_byte_pos}
  #     end

  #   write_sstable_and_index(rest, device, next_acc)
  # end

  # defp write_sstable_and_index([], _device, {_byte_pos, idx, _last_byte_pos}) do
  #   idx
  # end
end
