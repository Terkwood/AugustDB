defmodule SSTable.Settings do
  def kv_length_bytes do
    8
  end

  @t 4_294_967_296 - 1
  def tombstone do
    @t
  end

  @index_chunk_size 4 * 1024
  @doc """
  Defines how sparse the index file should be.
  The application will only write one `key -> offset`
  value per this many bytes.
  """
  def index_chunk_size do
    # ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️HACKED! ⚠️⚠️⚠️⚠️⚠️
    # ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️HACKED! ⚠️⚠️⚠️⚠️⚠️
    # ⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️HACKED! ⚠️⚠️⚠️⚠️⚠️
    125
  end
end
