defmodule SSTable.Zip do
  def create_checksum(uncompressed_payload) do
    <<:erlang.crc32(uncompressed_payload)::32>>
  end

  def verify_checksum(compressed_payload, crc32_checksum) do
    pl = :binary.bin_to_list(compressed_payload)

    payload_checksum = Enum.reverse(pl) |> Enum.drop(4) |> Enum.take(4)

    case payload_checksum == :binary.bin_to_list(crc32_checksum) do
      true -> :ok
      false -> :fail
    end
  end
end
