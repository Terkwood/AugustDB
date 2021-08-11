NimbleCSV.define(CommitLogParser, separator: TSV.col_separator(), escape: "\"")

defmodule CommitLog do
  use GenServer
  @moduledoc """
  Server tracks the device associated with a commit log file,
  as well as the filename to which we're writing.
  """

  import CommitLog.Path

  @tsv_header_string "k\tv\tt\tc\n"
  @tombstone_string Tombstone.string()
  @log_file "commit.log"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: CommitLogDevice)
  end

  def init(nil) do
    path = new_path()
    {:ok, device} = :file.open(path, [:append])
    {:ok, {device, path}}
  end

  def handle_cast(:new, {last_device, last_path}) do
    :ok = :file.close(last_device)
    :ok = :file.delete(last_path)
    next_path = new_path()
    {:ok, next_device} = :file.open(next_path, [:append, :raw])
    {:noreply, {next_device, next_path}}
  end


  def handle_cast({:append, payload}, {device, path}) do
    :file.write(device, payload)
    {:noreply, {device, path}}
  end

  def append(key, :tombstone) do
    __MODULE__.append(key, @tombstone_string)
  end

  def append(key, value) do
    ## MAKE SURE TO ONLY USE THE :file.write FUNCTION
    # https://erlang.org/doc/man/file.html#open-2
    <<crc32::32>> = Checksum.create(key <> value)

    GenServer.cast(
      CommitLogDevice,
      {:append,
       key <>
         TSV.col_separator() <>
         value <>
         TSV.col_separator() <>
         "#{:erlang.monotonic_time()}" <>
         TSV.col_separator() <>
         Integer.to_string(crc32, 16) <>
         TSV.row_separator()}
    )
  end

  @doc """
  Replay all commit log values into the memtable.
  """
  def replay() do
    raise "TODO: rework me"
    # we need the header line so that NimbleCSV doesn't fail
    hdr = Stream.cycle([@tsv_header_string]) |> Stream.take(1)
    log = File.stream!(@log_file, read_ahead: 100_000)

    Stream.concat(hdr, log)
    |> CommitLogParser.parse_stream()
    |> Stream.map(fn stuff ->
      case stuff do
        [k, v, _, crc32_string] when v == @tombstone_string ->
          {crc32, _} = Integer.parse(crc32_string, 16)

          case Checksum.verify(k <> v, crc32) do
            :ok -> Memtable.delete(k)
            :fail -> IO.puts("CommitLog failed to verify checksum for #{k}: discarding")
          end

        [k, v, _, crc32_string] ->
          {crc32, _} = Integer.parse(crc32_string, 16)

          case Checksum.verify(k <> v, crc32) do
            :ok -> Memtable.delete(k)
            :fail -> IO.puts("CommitLog failed to verify checksum for #{k}: discarding")
          end

          Memtable.update(k, v)

        unknown ->
          IO.puts(:stderr, "CommitLogParser cannot interpret #{unknown}: discarding")
      end
    end)
    |> Stream.run()
  end

  def touch() do
    File.touch!(@log_file)
  end

  @doc """
  Delete the old commit log and open a device  to a new one
  in raw,append mode.
  """
  def new() do
    GenServer.cast(CommitLogDevice, :new)
  end
end
