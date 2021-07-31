NimbleCSV.define(SSTableParser, separator: TSV.col_separator(), escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  @csv_header TSV.header_kv()
  @csv_header_string TSV.header_string()
  @csv_header_bytes TSV.header_bytes()
  @csv_row_separator TSV.row_separator()
  @tombstone_string Tombstone.string()

  @doc """
  Dump a list of key/value pairs to an IO-ready CSV stream, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index
      %{
        "k1" => 4,
        "k2" => 9,
        "k3" => 15,
      }

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> IO.iodata_to_binary(Enum.to_list(them.table))
      "k\tv\\nk1\tv\\nk2\tww\\nk3\tuuu\\n"

  """
  def dump(keyvals) when is_list(keyvals) do
    csv_header = SSTableParser.dump_to_stream(@csv_header)
    csv_stream = SSTableParser.dump_to_stream(keyvals)

    rlens =
      for row <- csv_stream do
        rl = row_length(row)
        key = if length(row) > 0, do: hd(row), else: ""
        {key, rl}
      end

    {index, _acc} =
      Enum.map_reduce(rlens, @csv_header_bytes, fn {key, l}, acc -> {{key, acc}, acc + l} end)

    %__MODULE__{index: Map.new(index), table: Stream.concat(csv_header, csv_stream)}
  end

  def from(memtable) do
    maybe_kvs =
      for entry <- :gb_trees.to_list(memtable) do
        case entry do
          {key, {:value, value, _time}} -> [key, value]
          {key, {:tombstone, _time}} -> [key, @tombstone_string]
          _ -> nil
        end
      end

    kvs = Enum.filter(maybe_kvs, &(&1 != nil))

    dump(kvs)
  end

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
  iex(3)> Memtable.update("bar","BAZ"); Memtable.delete("foo"); Memtable.flush()
  :ok
  iex(4)> SSTable.query_all("bar")
  "BAZ"
  iex(5)> SSTable.query_all("foo")
  :tombstone
  iex(6)> SSTable.query_all("a")
  :none
  ```
  """
  def query_all(key) do
    sst_files = Path.wildcard("*.sst")
    query_all(key, sst_files)
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

  defp query(key, sst_file_or_timestamp) do
    file_timestamp = hd(String.split("#{sst_file_or_timestamp}", ".sst"))

    {:ok, index_bin} = File.read("#{file_timestamp}.idx")
    index = :erlang.binary_to_term(index_bin)

    maybe_offset =
      case Map.get(index, key) do
        nil -> :none
        offset -> offset
      end

    maybe_value =
      case maybe_offset do
        :none -> :none
        offset -> seek("#{file_timestamp}.sst", offset)
      end

    case maybe_value do
      :none -> :none
      [_, t] when t == @tombstone_string -> :tombstone
      [_, v] -> v
    end
  end

  @seek_bytes 64
  @read_ahead_bytes @seek_bytes * 1000
  defp seek(file_name, offset) do
    {:ok, file} = :file.open(file_name, [:read, :binary, {:read_ahead, @read_ahead_bytes}])
    out = SSTableParser.parse_string(@csv_header_string <> keep_reading(file, offset))
    :file.close(file)

    case out do
      [[k, v]] -> [k, v]
      _ -> :none
    end
  end

  defp keep_reading(file, from, acc \\ "") do
    case :file.pread(file, from, @seek_bytes) do
      {:ok, data} ->
        case stop_at_row_separator(data) do
          :continue -> keep_reading(file, from + @seek_bytes, acc <> data)
          {:stop, up_to_sep} -> acc <> up_to_sep
        end

      :eof ->
        acc
    end
  end

  defp stop_at_row_separator(data) do
    case String.split(data, @csv_row_separator) do
      [_just_one] ->
        :continue

      [] ->
        {:stop, ""}

      many ->
        {:stop, hd(many)}
    end
  end

  defp row_length(row) when is_list(row) do
    ints =
      for int_col <- row, is_integer(int_col) do
        1
      end

    strs =
      for str_col <- row, is_binary(str_col) do
        String.length(str_col)
      end

    Enum.sum(ints) + Enum.sum(strs)
  end
end
