NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

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
