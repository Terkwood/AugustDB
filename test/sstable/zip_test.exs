defmodule ZipTest do
  use ExUnit.Case, async: true

  import SSTable.Zip

  test "payload accumulates for small inputs" do
    r = zip([{"a", "b"}, {"aa", "bb"}])
    IO.inspect(r)
    assert byte_size(r.payload) > 0
  end
end
