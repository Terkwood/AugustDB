defmodule SSTable.Settings do
  def kv_length_bytes do
    8
  end

  def tombstone do
    4_294_967_296
  end
end
