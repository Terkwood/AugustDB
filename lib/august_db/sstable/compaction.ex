defmodule SSTable.Compaction do
  import SSTable.Settings

  @moduledoc """
  SSTable Compaction
  """

  @doc """
  Run compaction on all SSTables, generating a Sorted String Table file
  (.sst) and an erlang binary representation of its index (key to byte
  offset) as a `.idx` file.  The index is sparse, having only one entry
  per `SSTable.Settings.index_chunk_size` bytes.
  """
  def run do
    old_sst_paths = Enum.sort(Path.wildcard("*.sst"))

    case merge_gz_chunks(old_sst_paths) do
      :noop ->
        :noop

      {sst_filename, sparse_index} ->
        for p <- old_sst_paths do
          File.rm!(p)
          File.rm!(hd(String.split(p, ".sst")) <> ".idx")
        end

        # save the new index into main memory
        SSTable.Index.remember(sst_filename, sparse_index)

        # evict all the defunct indices from main memory
        SSTable.Index.evict()

        sst_filename
    end
  end

  defmodule Periodic do
    use GenServer

    @compaction_period_seconds 60

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
      schedule_work()
      {:ok, state}
    end

    def handle_info(:work, state) do
      case SSTable.Compaction.run() do
        :noop ->
          nil

        compacted_sst_filename ->
          IO.puts("Compacted #{compacted_sst_filename}")
      end

      # Do it again
      schedule_work()
      {:noreply, state}
    end

    defp schedule_work() do
      Process.send_after(self(), :work, @compaction_period_seconds * 1000)
    end
  end

  defmodule Sort do
    @doc """
    Finds the lowest _and_ most recent key across multiple file
    segments.
    """
    @spec lowest_most_recent([{any, any}, ...]) :: {any, any}
    def lowest_most_recent([{k, v} | newer]) do
      lowest([{k, v} | newer], {k, v})
    end

    def lowest([], {acc_k, acc_v}) do
      {acc_k, acc_v}
    end

    def lowest([{next_k, next_v} | newer], {acc_k, acc_v}) do
      if next_k <= acc_k do
        lowest(newer, {next_k, next_v})
      else
        lowest(newer, {acc_k, acc_v})
      end
    end
  end

  defmodule IndexAcc do
    defstruct index: [],
              current_offset: 0,
              last_offset: nil
  end

  defmodule Chunk do
    defstruct [:unzipped, :gz_offset]
  end

  @tombstone tombstone()
  defp merge_gz_chunks(paths) when is_list(paths) do
    case paths do
      [] ->
        :noop

      [_one] ->
        :noop

      many_paths ->
        many_devices =
          Enum.map(many_paths, fn p ->
            {:ok, device} = :file.open(p, [:read, :raw])
            device
          end)

        many_kv_devices_chunks =
          many_devices
          |> Enum.map(fn device ->
            read_next_kv(device, %Chunk{unzipped: <<>>, gz_offset: 0})
          end)
          |> Enum.filter(fn maybe_eof ->
            case maybe_eof do
              :eof -> false
              _ -> true
            end
          end)

        output_path = SSTable.new_filename()

        {:ok, output_sst} = :file.open(output_path, [:raw, :append])

        index =
          compare_and_write_chunks(
            many_kv_devices_chunks,
            output_sst,
            [],
            %Chunk{
              unzipped: <<>>,
              gz_offset: 0
            },
            nil
          )

        Enum.map(many_devices, &:file.close(&1))
        :ok = :file.close(output_sst)

        index_binary = :erlang.term_to_binary(index)
        index_path = hd(String.split(output_path, ".sst")) <> ".idx"
        File.write!(index_path, index_binary)

        {output_path, index}
    end
  end

  # defp merge(paths) when is_list(paths) do
  #   case paths do
  #     [] ->
  #       :noop

  #     [_one] ->
  #       :noop

  #     many_paths ->
  #       output_path = SSTable.new_filename()

  #       many_devices =
  #         Enum.map(many_paths, fn p ->
  #           {:ok, f} = :file.open(p, [:read, :raw])
  #           f
  #         end)

  #       {:ok, output_sst} = :file.open(output_path, [:raw, :append])

  #       many_kv_devices =
  #         many_devices
  #         |> Enum.map(&{&1, 0})
  #         |> Enum.map(fn {device, offset} ->
  #           read_one(device, offset)
  #         end)
  #         |> Enum.filter(fn maybe_eof ->
  #           case maybe_eof do
  #             :eof -> false
  #             _ -> true
  #           end
  #         end)

  #       index = compare_and_write(many_kv_devices, output_sst, %IndexAcc{})

  #       Enum.map(many_devices, &:file.close(&1))
  #       :ok = :file.close(output_sst)

  #       index_binary = :erlang.term_to_binary(index)
  #       index_path = hd(String.split(output_path, ".sst")) <> ".idx"
  #       File.write!(index_path, index_binary)

  #       {output_path, index}
  #   end
  # end

  @gzip_length_bytes SSTable.Settings.gzip_length_bytes()
  @doc """
  Write a gzip length header followed by and a gzipped chunk of k/v pairs

  Return the size of the written data in bytes.
  """
  def write_chunk(gz_payload, device) do
    payload_size = byte_size(gz_payload)

    gz_length_header = <<payload_size::@gzip_length_bytes*8>>
    :ok = :file.write(device, gz_length_header)
    :ok = :file.write(device, gz_payload)

    @gzip_length_bytes + payload_size
  end

  defp compare_and_write_chunks(
         [],
         _outfile,
         index,
         _output_chunk,
         _maybe_first_chunk_key
       ) do
    index
  end

  defp compare_and_write_chunks(
         many_kv_devices_chunks,
         output_device,
         index,
         %Chunk{unzipped: output_payload, gz_offset: output_gz_offset},
         maybe_first_chunk_key
       )
       when is_list(many_kv_devices_chunks) do
    {the_lowest_key, the_lowest_value} =
      many_kv_devices_chunks
      |> Enum.map(fn {kv, _d, _chunk} -> kv end)
      |> Sort.lowest_most_recent()

    kv_bin = SSTable.KV.to_binary(the_lowest_key, the_lowest_value)

    wip_output = output_payload <> kv_bin

    chunk_size = byte_size(wip_output)

    next_chunk =
      if byte_size(wip_output) > SSTable.Settings.unzipped_data_chunk() do
        write_chunk(wip_output, output_device)
        %Chunk{unzipped: <<>>, gz_offset: output_gz_offset + chunk_size}
      else
        %Chunk{unzipped: wip_output, gz_offset: output_gz_offset}
      end

    next_round =
      many_kv_devices_chunks
      |> Enum.map(fn {kv, d, chunk} ->
        case kv do
          {k, _} when k == the_lowest_key ->
            read_next_kv(d, chunk)

          higher ->
            {higher, d, chunk}
        end
      end)

    should_write_sparse_index_entry =
      case next_chunk.unzipped do
        <<>> -> true
        _too_soon -> false
      end

    # if we just started a new chunk, we didn't learn about its
    # first key until just now...
    first_chunk_key =
      case maybe_first_chunk_key do
        nil -> the_lowest_key
        keep -> keep
      end

    # ...and we need first_chunk_key to write the sparse index
    next_index =
      if should_write_sparse_index_entry do
        [
          {first_chunk_key, output_gz_offset} | index
        ]
      else
        index
      end

    next_round
    |> Enum.filter(fn tuple_or_eof ->
      case tuple_or_eof do
        :eof -> false
        _ -> true
      end
    end)
    |> compare_and_write_chunks(output_device, next_index, next_chunk, first_chunk_key)
  end

  # defp compare_and_write([], _outfile, %IndexAcc{index: index, last_offset: _, current_offset: _}) do
  #   index
  # end

  # defp compare_and_write(many_kv_devices_offsets, outfile, %IndexAcc{
  #        index: index,
  #        current_offset: index_bytes,
  #        last_offset: last_offset
  #      })
  #      when is_list(many_kv_devices_offsets) do
  #   {the_lowest_key, the_lowest_value} =
  #     many_kv_devices_offsets
  #     |> Enum.map(fn {kv, _d, _offset} -> kv end)
  #     |> Sort.lowest_most_recent()

  #   segment_size = write_kv(the_lowest_key, the_lowest_value, outfile)

  #   next_round =
  #     many_kv_devices_offsets
  #     |> Enum.map(fn {kv, d, offset} ->
  #       case kv do
  #         {k, _} when k == the_lowest_key ->
  #           read_one(d, offset)

  #         higher ->
  #           {higher, d, offset}
  #       end
  #     end)

  #   should_write_sparse_index_entry =
  #     case last_offset do
  #       nil -> true
  #       lbp when lbp + @index_chunk_size < index_bytes -> true
  #       _too_soon -> false
  #     end

  #   next_acc =
  #     if should_write_sparse_index_entry do
  #       %IndexAcc{
  #         current_offset: segment_size + index_bytes,
  #         index: [
  #           {the_lowest_key, index_bytes} | index
  #         ],
  #         last_offset: index_bytes
  #       }
  #     else
  #       %IndexAcc{
  #         current_offset: segment_size + index_bytes,
  #         index: index,
  #         last_offset: last_offset
  #       }
  #     end

  #   next_round
  #   |> Enum.filter(fn tuple_or_eof ->
  #     case tuple_or_eof do
  #       :eof -> false
  #       _ -> true
  #     end
  #   end)
  #   |> compare_and_write(outfile, next_acc)
  # end

  @gzip_length_bytes SSTable.Settings.gzip_length_bytes()
  defp read_next_kv(device, %Chunk{unzipped: <<>>, gz_offset: gz_offset}) do
    IO.puts("base case")

    case :file.pread(device, gz_offset, @gzip_length_bytes) do
      :eof ->
        :eof

      {:ok, l} ->
        <<gzipped_chunk_size::@gzip_length_bytes*8>> = IO.iodata_to_binary(l)
        IO.inspect(gzipped_chunk_size)

        case :file.pread(device, gz_offset + @gzip_length_bytes, gzipped_chunk_size) do
          :eof ->
            :eof

          {:ok, next_gz_chunk} ->
            unzipped = :zlib.gunzip(IO.iodata_to_binary(next_gz_chunk))

            read_next_kv(device, %Chunk{
              unzipped: unzipped,
              gz_offset: gz_offset + @gzip_length_bytes + gzipped_chunk_size
            })
        end
    end
  end

  @key_length_bytes SSTable.Settings.key_length_bytes()
  @value_length_bytes SSTable.Settings.value_length_bytes()
  defp read_next_kv(device, %Chunk{
         unzipped: payload,
         gz_offset: gz_offset
       }) do
    <<key_len::@key_length_bytes*8, value_len::@value_length_bytes*8, etc1::binary>> = payload

    <<key::binary-size(key_len), etc2::binary>> = etc1

    case value_len do
      @tombstone ->
        {{key, :tombstone}, device, %Chunk{unzipped: etc2, gz_offset: gz_offset}}

      vl ->
        <<value::binary-size(vl), etc3::binary>> = etc2
        {{key, value}, device, %Chunk{unzipped: etc3, gz_offset: gz_offset}}
    end
  end

  # defp read_one(device, offset) do
  #   case :file.pread(device, offset, kv_length_bytes()) do
  #     :eof ->
  #       :eof

  #     {:ok, l} ->
  #       <<key_len::32, value_len::32>> = IO.iodata_to_binary(l)

  #       case :file.pread(device, offset + kv_length_bytes(), key_len) do
  #         {:ok, key_data} ->
  #           key = IO.iodata_to_binary(key_data)

  #           case value_len do
  #             @tombstone ->
  #               next_offset = offset + kv_length_bytes() + key_len
  #               {{key, :tombstone}, device, next_offset}

  #             vl ->
  #               {:ok, value_data} = :file.pread(device, offset + kv_length_bytes() + key_len, vl)
  #               value = IO.iodata_to_binary(value_data)
  #               next_offset = offset + kv_length_bytes() + key_len + vl
  #               {{key, value}, device, next_offset}
  #           end

  #         :eof ->
  #           :eof
  #       end
  #   end
  # end
end
