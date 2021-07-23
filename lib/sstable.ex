NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  @csv_header [["k", "v"]]
  @csv_header_string "k\tv\n"
  @csv_header_bytes 4
  @csv_row_separator "\n"

  @doc """
  Dump a list of key/value pairs to an IO-ready CSV stream, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index

      index: [
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

  def seek(file_name, _key, offset \\ 0) do
    {:ok, file} = :file.open(file_name, [:read, :binary])
    :file.position(file, offset)
    SSTableParser.parse_string(@csv_header_string <> keep_reading(file))
  end

  @seek_bytes 64
  defp keep_reading(file, acc \\ "") do
    case :file.read(file, @seek_bytes) do
      {:ok, data} ->
        case stop_at_row_separator(data) do
          :continue -> keep_reading(file, acc <> data)
          {:stop, up_to_sep} -> acc <> up_to_sep
        end

      :eof ->
        acc
    end
  end

  defp stop_at_row_separator(data) do
    IO.inspect(data)

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
