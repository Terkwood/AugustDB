defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  @doc """
  Thanks to https://dev.to/diogoko/random-strings-in-elixir-e8i
  """
  def rand_string do
    for _ <- 1..1024, into: "", do: <<Enum.random('0123456789abcdef')>>
  end

  test "payload accumulates for small inputs" do
    result = zip([{"a", "b"}, {"aa", "bb"}])
    assert byte_size(result.payload) > 0
  end

  test "back and forth" do
    input = [
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()},
      {rand_string(), rand_string()}
    ]

    result = zip(input)
    IO.inspect(byte_size(result.payload))
    assert byte_size(result.payload) > 0
    IO.inspect(Enum.count(result.index))
  end
end
