NimbleCSV.define(CommitLogParser, separator: "\t", escape: "\"")

defmodule CommitLog do
  @tsv_header_string "k\tv\tt\n"
  @tombstone_string Tombstone.string()

  def append(key, :tombstone) do
    __MODULE__.append(key, @tombstone_string)
  end

  def append(key, value) do
    File.write!(
      __MODULE__.log_path(),
      key <> "\t" <> value <> "\t" <> "#{:erlang.monotonic_time()}" <> "\n",
      [:append]
    )
  end

  def replay() do
    # we need the header line so that NimbleCSV doesn't fail
    hdr = Stream.cycle([@tsv_header_string]) |> Stream.take(1)
    log = File.stream!(__MODULE__.log_path(), read_ahead: 100_000)

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

  def trim() do
    raise "todo"
  end

  def log_path() do
    "commit.log"
  end

  defmodule Trimmer do
    @moduledoc """
    Run this using `:timer.apply_interval` and figure
    out whether the commit log needs to be trimmed.

    If it does, call `CommitLog.trim()`.
    """

    # Approximately one second
    @mono_tick 1_000_000_000
    # Trim after this many ticks
    # NB We should also guarantee that Memtable is flushed
    # ...more frequently than this
    @trim_after 15 * 60 * @mono_tick

    def must_trim() do
      IO.inspect(CommitLog.log_path())
      raise "todo return bool"
    end
  end
end
