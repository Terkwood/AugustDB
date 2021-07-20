NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  defstruct [:index, :table]

  def dump(keyvals) when is_list(keyvals) do
    s = SSTableParser.dump_to_stream(keyvals)

    index =
      List.flatten(
        for everything <- s do
          skip_separators = Enum.drop_every([nil | everything], 2)

          {is, _acc} =
            Enum.map_reduce(skip_separators, 0, fn row, acc ->
              {{row, acc}, String.length(row) + acc}
            end)

          is
        end
      )

    %__MODULE__{index: index, table: s}
  end
end
