defmodule SSTable.Zip do
  defmodule Index do
    defstruct [:key, :offset]
  end

  defmodule ChunkAccum do
    defstruct [:payload, :last_index, :current_offset]

    def empty do
      %__MODULE__{payload: <<>>, last_index: nil, current_offset: 0}
    end
  end

  def zip(kvs) do
    kvs
    |> Enum.reduce(ChunkAccum.empty(), fn %ChunkAccum{
                                            payload: payload,
                                            last_index: last_index,
                                            current_offset: current_offset
                                          },
                                          acc ->
      raise "todo"
    end)
  end

  def create_gzipped_chunks_fail(kvs) do
    {leftover, all_chunks, _, last_byte_pos, idx, last_key} =
      kvs
      |> Enum.reduce({<<>>, [], 0, 0, [], nil}, fn {key, value},
                                                   {current_chunk, all_chunks, current_byte_pos,
                                                    last_byte_pos, idx, last_key} ->
        kv_bin = SSTable.KV.to_binary(key, value)

        keep_last_key =
          case last_key do
            nil -> key
            l -> l
          end

        if last_byte_pos + payload_size >= SSTable.Settings.index_chunk_size() do
          {<<>>, [gz_payload | all_chunks], next_byte_pos, current_byte_pos,
           [{key, last_byte_pos} | idx], nil}
        else
          {current_chunk <> more_payload, all_chunks, next_byte_pos, last_byte_pos, idx,
           keep_last_key}
        end
      end)

    case {leftover, last_key} do
      {bin, k} when k != nil ->
        {[bin | all_chunks], [{last_key, last_byte_pos} | idx]}

      _ ->
        {all_chunks, idx}
    end
  end
end
