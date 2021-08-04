defmodule SSTable.Write do
  @tombstone SSTable.Settings.tombstone()

  @doc """
  Write a length header, and key/value combination in binary to a device.

  Return the size of the segment written.
  """
  def write_kv(key, value, device) do
    ks = byte_size(key)

    segment_size =
      case value do
        :tombstone ->
          kl = <<ks::32>>
          vl = <<@tombstone::32>>
          :ok = :file.write(device, kl)
          :ok = :file.write(device, vl)
          :ok = :file.write(device, key)
          byte_size(kl) + byte_size(vl) + byte_size(key)

        bin when is_binary(bin) ->
          vs = byte_size(bin)
          kvl = <<ks::32, vs::32>>
          :ok = :file.write(device, kvl)
          :ok = :file.write(device, key)
          :ok = :file.write(device, bin)
          byte_size(kvl) + byte_size(key) + byte_size(bin)
      end

    segment_size
  end
end
