NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  @csv_header [["k", "v"]]
  @csv_header_string "k\tv\n"
  @csv_header_bytes 4
  @csv_row_separator "\n"
  @tombstone_string "$T$"

  @doc """
  Dump a list of key/value pairs to an IO-ready CSV stream, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index
      [
        {"k1", 4},
        {"k2", 9},
        {"k3", 15},
      ]

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

    %__MODULE__{index: index, table: Stream.concat(csv_header, csv_stream)}
  end

  @doc """
  Query an SSTable file using its associated index file and a key,
  returning a value if present. Filters tombstone entries.

  There must be an associated `<timestamp>.idx` file present,
  or this function will fail.

  ## Example

  ```elixir
  SSTable.query("1627340924286645039.sst", "a")
  SSTable.query(1627340924286645039, "a")
  ```
  """
  def query(sst_file_or_timestamp, key) do
    file_timestamp = hd(String.split("#{sst_file_or_timestamp}", ".sst"))

    {:ok, index_bin} = File.read("#{file_timestamp}.idx")
    index = :erlang.binary_to_term(index_bin)

    maybe_offset =
      case Enum.find(index, fn {a, _offset} -> a == key end) do
        nil -> :none
        {_, t} when t == @tombstone_string -> :none
        {a, offset} when a == key -> offset
      end

    case maybe_offset do
      :none -> :none
      offset -> seek("#{file_timestamp}.sst", offset)
    end
  end

  defp seek(file_name, offset) do
    {:ok, file} = :file.open(file_name, [:read, :binary])
    out = SSTableParser.parse_string(@csv_header_string <> keep_reading(file, offset))
    :file.close(file)

    case out do
      [[k, v]] -> [k, v]
      _ -> :none
    end
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

  @seek_bytes 64
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
