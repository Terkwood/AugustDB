NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  @spec dump(maybe_improper_list) :: %SSTable{index: list, table: list}
  @doc """
  Dump a list of key/value pairs to an IO-ready CSV stream, accompanied by an index of offsets.

  ## Example

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> them.index

      index: [
        {"k1", 0},
        {"k2", 5},
        {"k3", 11},
      ]

      iex> them = SSTable.dump([~w(k1 v), ~w(k2 ww), ~w(k3 uuu)])
      iex> IO.iodata_to_binary(Enum.to_list(them.table))
      "k1\tv\\nk2\tww\\nk3\tuuu\\n"

  """
  def dump(keyvals) when is_list(keyvals) do
    csv_stream = SSTableParser.dump_to_stream(keyvals)

    rlens =
      for row <- csv_stream do
        rl = row_length(row)
        key = if length(row) > 0, do: hd(row), else: ""
        {key, rl}
      end

    {index, _acc} = Enum.map_reduce(rlens, 0, fn {key, l}, acc -> {{key, acc}, acc + l} end)

    %__MODULE__{index: index, table: csv_stream}
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
