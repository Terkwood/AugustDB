NimbleCSV.define(CommitLogParser, separator: TSV.col_separator(), escape: "\"")

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
      key <>
        TSV.col_separator() <>
        value <> TSV.col_separator() <> "#{:erlang.monotonic_time()}" <> TSV.row_separator(),
      [:append]
    )
  end

  @doc """
  Replay all commit log values into the memtable.
  """
  def replay() do
    # we need the header line so that NimbleCSV doesn't fail
    hdr = Stream.cycle([@tsv_header_string]) |> Stream.take(1)
    log = File.stream!(@log_file, read_ahead: 100_000)

    Stream.concat(hdr, log)
    |> CommitLogParser.parse_stream()
    |> Stream.map(fn stuff ->
      case stuff do
        [k, v, _] when v == @tombstone_string -> Memtable.delete(k)
        [k, v, _] -> Memtable.update(k, v)
        unknown -> IO.puts(:stderr, "CommitLogParser cannot interpret #{unknown}: discarding")
      end
    end)
    |> Stream.run()
  end

  def backup() do
    output_path = "#{@log_file}.#{:erlang.system_time()}.bak"
    File.copy!(@log_file, output_path)
    output_path
  end

  def touch() do
    File.touch!(@log_file)
  end

  def new() do
    File.rm!(@log_file)
    File.touch!(@log_file)
  end
end
