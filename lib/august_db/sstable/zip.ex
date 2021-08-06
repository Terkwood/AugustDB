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
        chunk_offset: nil,
        index: [],
        current_offset: 0
      }
    end
  end

  # wild guess at how much uncompressed data we should read in before gzipping
  @uncompressed_data_chunk SSTable.Settings.unzipped_data_chunk()
  def zip(kvs) do
    case kvs
         |> Enum.reduce(
           ChunkAccum.empty(),
           fn {key, value},
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
               chunk_size = <<byte_size(gzip_chunk)::32>>

               %ChunkAccum{
                 payload: payload <> chunk_size <> gzip_chunk,
                 current_chunk: <<>>,
                 index: [{next_chunk_key, next_chunk_offset} | index],
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
           end
         ) do
      c when byte_size(c.payload) == 0 ->
        gzip_one_chunk = :zlib.gzip(c.current_chunk)
        chunk_size = <<byte_size(gzip_one_chunk)::32>>

        {chunk_size <> gzip_one_chunk, [{c.chunk_key, c.chunk_offset} | c.index]}

      c ->
        {c.payload, c.index}
    end
  end
end
