NimbleCSV.define(SSTableParser, separator: "\t", escape: "\"")

defmodule SSTable do
  def dump(keyvals) when is_list(keyvals) do
    s = SSTableParser.dump_to_stream([keyvals])

    for everything <- s do
      skip_separators = Enum.drop_every([nil | everything], 2)

      for row <- skip_separators do
        IO.puts("#{row} length #{String.length(row)}")
      end
    end
  end
end
