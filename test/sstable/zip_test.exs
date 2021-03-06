defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  test "payload accumulates for small inputs" do
    {payload, _index} = zip([{"a", "b"}, {"yaa", "bb"}])
    assert byte_size(payload) > 0
  end

  test "back and forth" do
    {payload, _index} = zip([{"maybe", "knot"}, {"no", "yes"}])

    <<_chunk_size::32, rest::binary>> = payload

    <<first_key_size::32, first_value_size::32, rest_unzipped::binary>> = :zlib.gunzip(rest)

    assert first_key_size == byte_size("maybe")
    assert first_value_size == byte_size("knot")
    <<maybe::binary-size(5), knot::binary-size(4), no_yes_bin::binary>> = rest_unzipped
    assert maybe == "maybe"
    assert knot == "knot"

    # KEEP GOING!
    <<second_key_size::32, second_value_size::32, no::binary-size(2), yes::binary-size(3)>> =
      no_yes_bin

    assert second_key_size == byte_size("no")
    assert second_value_size == byte_size("yes")
    assert no == "no"
    assert yes == "yes"
  end

  test "adding more data produces an index with multiple entries" do
    input = big_data()

    {_payload, index} = zip(input)

    assert Enum.count(index) > 1
  end

  test "zip reduces final payload size vs uncompressed binary KV format" do
    input = big_data()

    {payload, _index} = zip(input)

    size_of_payload = byte_size(payload)

    size_of_raw_kvs =
      input
      |> Enum.reduce(0, fn {k, v}, acc -> 8 + byte_size(SSTable.KV.to_binary(k, v)) + acc end)

    assert size_of_payload < size_of_raw_kvs
  end

  @doc """
  Thanks to https://dev.to/diogoko/random-strings-in-elixir-e8i
  """
  def rand_string do
    for _ <- 1..1024, into: "", do: <<Enum.random('0123456789abcdef')>>
  end

  defp big_data do
    [
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()}
    ]
  end
end
