defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  test "payload accumulates for small inputs" do
    {payload, index} = zip([{"a", "b"}, {"yaa", "bb"}])
    assert byte_size(payload) > 0
  end

  test "back and forth" do
    {payload, index} = zip([{"maybe", "not"}, {"no", "yes"}])

    <<chunk_size::32, rest::binary>> = payload

    IO.inspect(chunk_size)

    <<first_key_size::32, first_value_size::32, rest_plain::binary>> = :zlib.gunzip(rest)
    IO.inspect(index)
    IO.inspect(first_key_size)
    IO.inspect(first_value_size)
  end

  test "adding more data produces an index with multiple entries" do
    input = big_data()

    {payload, index} = zip(input)

    assert Enum.count(index) > 1
  end

  test "zip reduces final payload size vs uncompressed binary KV format" do
    input = big_data()

    {payload, index} = zip(input)

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
