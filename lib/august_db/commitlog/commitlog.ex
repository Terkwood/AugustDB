NimbleCSV.define(CommitLogParser, separator: TSV.col_separator(), escape: "\"")

defmodule CommitLog do
  use GenServer
  @moduledoc """
  Server tracks the device associated with a commit log file,
  as well as the filename to which we're writing.

  ## Caveats

  There's some annoying state management that has to be taken care of
  to support the replay functionality: individual replays must be
  announced to the CommitLog genserver with a
  `{:begin_replay, some_commitlog_path}` message.

  Then when the replay is complete, it must be announced via
  `:end_replay`. This will prevent accidental deletions of commit
  logs which are being read, in case the log is huge and
  memtable flushes while it's being processed.
  """

  import CommitLog.Path

  @tsv_header_string "k\tv\tt\tc\n"
  @tombstone_string Tombstone.string()

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: CommitLogDevice)
  end

  def init(nil) do
    path = new_path()
    {:ok, device} = :file.open(path, [:append])
    {:ok, {device, path, nil}}
  end

  def handle_call({:can_delete?, inactive_path}, _from, {device, current_path, replay_path}) do
    answer = !(inactive_path == current_path || inactive_path == replay_path)
    {:reply, answer, {device, current_path, replay_path}}
  end

  @doc """
  We don't want to honor this call to swap the commit log
  during a replay event, because that would delete the file
  that we're reading from!
  """
  def handle_call(:swap, _from, {last_device, last_path, replay}) do
    case replay do
      nil ->
        :ok = :file.close(last_device)
        next_path = new_path()
        {:ok, next_device} = :file.open(next_path, [:append, :raw])
        {:reply, {:last_path, last_path}, {next_device, next_path, replay}}
      some_path ->
        {:reply, {:last_path, last_path}, {last_device, last_path, some_path}}
    end
  end

  def handle_cast({:begin_replay, path}, {device, write_path, _}) do
    {:noreply, {device, write_path, path}}
  end

  def handle_cast(:end_replay, {device, write_path, _}) do
    {:noreply, {device, write_path, nil}}
  end

  def handle_cast({:append, payload}, {device, path, replay}) do
    :file.write(device, payload)
    {:noreply, {device, path, replay}}
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
  Start a new commit log with an output device in raw & append
  modes.
  """
  def swap() do
    GenServer.call(CommitLogDevice, :swap)
  end

  @doc """
  Replay all commit log values into the memtable.
  """
  def replay() do
    Path.wildcard("commit-*.log") |>
      Enum.sort() |>
      Enum.filter(&GenServer.call(CommitLogDevice, {:can_delete?, &1})) |>
      Enum.map(&replay_one(&1)) |>
      Enum.each(fn inactive_path ->
        Memtable.flush()
        CommitLog.delete(inactive_path)
      end)
  end

  def delete(inactive_path) do
    # Just to be on the safe side, make sure we aren't
    # currently writing to the file we want to delete.
    if GenServer.call(CommitLogDevice, {:can_delete?, inactive_path}) do
      File.rm!(inactive_path)
    else
      IO.puts(:stderr, "Skipping delete of commit log: #{inactive_path}")
    end
  end

  defp replay_one(log_file) do
    # we want to make sure we don't accidentally delete
    # the file after memtable flush
    GenServer.cast(CommitLogDevice, {:begin_replay, log_file})
    IO.puts("Replaying #{log_file}")
    # we need the header line so that NimbleCSV doesn't fail
    hdr = Stream.cycle([@tsv_header_string]) |> Stream.take(1)

    log = File.stream!(log_file, read_ahead: 100_000)

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

    GenServer.cast(CommitLogDevice, :end_replay)
    log_file
  end
end
