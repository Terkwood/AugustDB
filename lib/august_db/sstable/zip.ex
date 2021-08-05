defmodule SSTable.Zip do
  defmodule Index do
    defstruct [:key, :offset]
  end

  defmodule ChunkAccum do
    defstruct [:payload, :current_chunk, :chunk_key, :chunk_offset, :index, :current_offset]

    def empty do
      %__MODULE__{
        payload: <<>>,
        current_chunk: <<>>,
        chunk_key: nil,
        chunk_offset: 0,
        index: [],
        current_offset: 0
      }
    end
  end

  # wild guess at how much uncompressed data we should read in before gzipping
  @uncompressed_data_chunk SSTable.Settings.index_chunk_size() * 1
  def zip(kvs) do
    kvs
    |> Enum.reduce(ChunkAccum.empty(), fn {key, value},
                                          %ChunkAccum{
                                            payload: payload,
                                            current_chunk: current_chunk,
                                            chunk_key: chunk_key,
                                            chunk_offset: chunk_offset,
                                            index: index,
                                            current_offset: current_offset
                                          } ->
      kv_bin = SSTable.KV.to_binary(key, value)

      {next_chunk_key, next_chunk_offset} =
        case {chunk_key, chunk_offset} do
          {nil, nil} -> {key, current_offset}
          nck -> nck
        end

      if byte_size(current_chunk) + byte_size(kv_bin) >= @uncompressed_data_chunk do
        gzip_chunk = :zlib.gzip(current_chunk <> kv_bin)

        %ChunkAccum{
          payload: payload <> gzip_chunk,
          current_chunk: <<>>,
          index: [next_chunk_key | index],
          chunk_key: nil,
          chunk_offset: nil,
          current_offset: current_offset + byte_size(gzip_chunk)
        }
      else
        %ChunkAccum{
          payload: payload,
          current_chunk: current_chunk <> kv_bin,
          index: index,
          chunk_key: next_chunk_key,
          chunk_offset: next_chunk_offset,
          current_offset: current_offset
        }
      end
    end)
  end

  # def create_gzipped_chunks_fail(kvs) do
  #   {leftover, all_chunks, _, last_byte_pos, idx, last_key} =
  #     kvs
  #     |> Enum.reduce({<<>>, [], 0, 0, [], nil}, fn {key, value},
  #                                                  {current_chunk, all_chunks, current_byte_pos,
  #                                                   last_byte_pos, idx, last_key} ->
  #       kv_bin = SSTable.KV.to_binary(key, value)

  #       keep_last_key =
  #         case last_key do
  #           nil -> key
  #           l -> l
  #         end

  #       # if last_byte_pos + payload_size >= SSTable.Settings.index_chunk_size() do
  #       #   {<<>>, [gz_payload | all_chunks], next_byte_pos, current_byte_pos,
  #       #    [{key, last_byte_pos} | idx], nil}
  #       # else
  #       #   {current_chunk <> more_payload, all_chunks, next_byte_pos, last_byte_pos, idx,
  #       #    keep_last_key}
  #       # end
  #     end)

  #   case {leftover, last_key} do
  #     {bin, k} when k != nil ->
  #       {[bin | all_chunks], [{last_key, last_byte_pos} | idx]}

  #     _ ->
  #       {all_chunks, idx}
  #   end
  # end
end
