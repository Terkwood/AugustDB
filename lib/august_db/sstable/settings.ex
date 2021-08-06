defmodule SSTable.Settings do
  def gzip_length_bytes do
    4
  end

  def kv_length_bytes do
    key_length_bytes() + value_length_bytes()
  end

  def key_length_bytes do
    4
  end

  def value_length_bytes do
    4
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
    @index_chunk_size
  end
end
