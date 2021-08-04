defmodule SSTable.Zip do
  def create_checksum(uncompressed_payload) do
    <<:erlang.crc32(uncompressed_payload)::32>>
  end

  @doc """
  Verifies a gzip checksum, per the
  [gzip file format](https://en.wikipedia.org/wiki/Gzip#File_format):

  > an 8-byte footer, containing a CRC-32 checksum and the
  > length of the original uncompressed data, modulo 2^32
  """
  def verify_checksum(compressed_payload, crc32_checksum) do
    pl = :binary.bin_to_list(compressed_payload)

    # not sure why we had to reverse this... but it works?!
    payload_checksum = Enum.reverse(pl) |> Enum.drop(4) |> Enum.take(4)

    case payload_checksum == :binary.bin_to_list(crc32_checksum) do
      true -> :ok
      false -> :fail
    end
  end
end
