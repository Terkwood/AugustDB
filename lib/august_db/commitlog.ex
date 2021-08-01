NimbleCSV.define(CommitLogParser, separator: "\t", escape: "\"")

defmodule CommitLog do
  @tsv_header_string "k\tv\tt\n"
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
    # we need the header line so that NimbleCSV doesn't fail
    hdr = Stream.cycle([@tsv_header_string]) |> Stream.take(1)
    log = File.stream!(@log_file, read_ahead: 100_000)

    # sketchy
    Memtable.clear()

    Stream.concat(hdr, log)
    |> CommitLogParser.parse_stream()
    |> Stream.map(fn [k, v, _] ->
      if v == @tombstone_string do
        Memtable.delete(k)
      else
        Memtable.update(k, v)
      end
    end)
    |> Stream.run()
  end

  def backup() do
    output_path = "#{@log_file}.#{:erlang.system_time()}.bak"
    File.copy!(@log_file, output_path)
    output_path
  end

  def new() do
    File.rm!(@log_file)
    File.touch!(@log_file)
  end
end
