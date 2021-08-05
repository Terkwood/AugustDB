defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  test "payload accumulates for small inputs" do
    {payload, index} = zip([{"a", "b"}, {"aa", "bb"}])
    assert byte_size(payload) > 0
  end

  test "back and forth" do
    {payload, index} = zip([{"no", "yes"}, {"maybe", "not"}])

    <<chunk_size::32, rest::binary>> = payload
  end

  test "adding more data eventually produces an indexed blob" do
    input = [
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

    {payload, index} = zip(input)

    assert byte_size(payload) > 0
    assert Enum.count(index) > 1

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
end
