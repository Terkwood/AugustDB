defmodule SSTable.KV do
  @tombstone SSTable.Settings.tombstone()
  def to_binary(key, value) do
    ks = byte_size(key)

    case value do
      :tombstone ->
        kl = <<ks::32>>
        vl = <<@tombstone::32>>
        kl <> vl <> key

      bin when is_binary(bin) ->
        vs = byte_size(bin)
        kvl = <<ks::32, vs::32>>
        kvl <> key <> bin
    end
  end
end
