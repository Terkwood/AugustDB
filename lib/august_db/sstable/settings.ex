defmodule SSTable.Settings do
  def kv_length_bytes do
    8
  end

  @t 4_294_967_296 - 1
  def tombstone do
    @t
  end
end
