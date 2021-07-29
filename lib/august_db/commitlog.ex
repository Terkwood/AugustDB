NimbleCSV.define(CommitLogParser, separator: "\t", escape: "\"")

defmodule CommitLog do
  @csv_header [["k", "v", "t"]]
  @csv_header_string "k\tv\tt\n"
  @csv_header_bytes 6
  @csv_row_separator "\n"
  @tombstone_string Tombstone.string()
  @log_file "commit.log"

  def append(key, :tombstone) do
    __MODULE__.append(key, @tombstone_string)
  end

  def append(key, value) do
    File.write!(@log_file, key <> "\t" <> value <> "\n", [:append])
  end
end
