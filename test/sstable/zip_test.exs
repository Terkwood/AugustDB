defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  test "payload accumulates for small inputs" do
    result = zip([{"a", "b"}, {"aa", "bb"}])
    assert byte_size(result.payload) > 0
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

    result = zip(input)

    assert byte_size(result.payload) > 0
    assert Enum.count(result.index) > 1
  end

  @doc """
  Thanks to https://dev.to/diogoko/random-strings-in-elixir-e8i
  """
  def rand_string do
    for _ <- 1..1024, into: "", do: <<Enum.random('0123456789abcdef')>>
  end
end
