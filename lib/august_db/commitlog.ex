NimbleCSV.define(CommitLogParser, separator: "\t", escape: "\"")

defmodule CommitLog do
  @tsv_header [["k", "v", "t"]]
  @tsv_header_string "k\tv\tt\n"
  @tsv_header_bytes 6
  @tsv_row_separator "\n"
  @tombstone_string Tombstone.string()
  @log_file "commit.log"

  def append(key, :tombstone) do
    __MODULE__.append(key, @tombstone_string)
  end

  def append(key, value) do
    File.write!(
      @log_file,
      key <> "\t" <> value <> "\t" <> "#{:erlang.monotonic_time()}" <> "\n",
      [:append]
    )
  end

  def replay() do
    raise "todo"
    # we need the header line so that NimbleCSV doesn't fail
    # hdr = SSTableParser.dump_to_stream(@tsv_header)
    log = File.stream!(@log_file, read_ahead: 100_000)

    Memtable.clear()

    # Stream.concat(hdr, log)
    log
    |> CommitLogParser.parse_stream()
    |> Stream.map(fn l ->
      IO.inspect(l)
      # Memtable.update(k, v)
    end)
    |> Stream.run()
  end
end
