defmodule SSTable.Zip do
  def create_gzipped_chunks(kvs) do
    {leftover, all_chunks, _, last_byte_pos, idx, last_key} =
      kvs
      |> Enum.reduce({<<>>, [], 0, 0, [], nil}, fn {key, value},
                                                   {current_chunk, all_chunks, current_byte_pos,
                                                    last_byte_pos, idx, last_key} ->
        kv_bin = SSTable.KV.to_binary(key, value)
        gz_payload = :zlib.gzip(kv_bin)
        payload_size = byte_size(gz_payload)

        next_byte_pos = current_byte_pos + payload_size

        keep_last_key =
          case last_key do
            nil -> key
            l -> l
          end

        if last_byte_pos + payload_size >= SSTable.Settings.index_chunk_size() do
          {<<>>, [current_chunk <> gz_payload | all_chunks], next_byte_pos, current_byte_pos,
           [{key, last_byte_pos} | idx], nil}
        else
          {current_chunk <> gz_payload, all_chunks, next_byte_pos, last_byte_pos, idx,
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
