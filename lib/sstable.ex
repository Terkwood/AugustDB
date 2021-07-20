NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  @spec dump(maybe_improper_list) :: %SSTable{index: list, table: binary}
  @doc """
  Dump a list of key/value pairs to text accompanied by an index of offsets.

  ## Example

      iex(82)> SSTable.dump([~w(key1 val1), ~w(key2 val20000), ~w(keywhatever whateverwatever), ~w(lastun ipromise)])
      %SSTable{
        index: [
          {"key1val1", 0},
          {"key2val20000", 8},
          {"keywhateverwhateverwatever", 20},
          {"lastunipromise", 46}
        ],
        table: "key1val1\tkey2val20000\tkeywhateverwhateverwatever\tlastunipromise\\n"
      }

  """
  def dump(keyvals) when is_list(keyvals) do
    d = SSTableParser.dump_to_stream([keyvals])

    index =
      List.flatten(
        for everything <- d do
          skip_separators = Enum.drop_every([nil | everything], 2)

          {is, _acc} =
            Enum.map_reduce(skip_separators, 0, fn row, acc ->
              {{row, acc}, String.length(row) + acc}
            end)

          is
        end
      )

    %__MODULE__{index: index, table: IO.iodata_to_binary(Enum.to_list(d))}
  end
end
