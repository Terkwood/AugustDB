defmodule ZipTest do
  use ExUnit.Case, async: true
  import SSTable.Zip

  test "create checksum" do
    cs = create_checksum("foo bar baz qux")
    assert cs == <<216, 38, 20, 177>>
  end

  test "verify checksum positive" do
    cs = create_checksum("foo bar baz qux")
    assert verify_checksum(:zlib.gzip("foo bar baz qux"), cs) == :ok
  end

  test "verify checksum negative" do
    bad_idea = <<214, 38, 21, 176>>
    assert verify_checksum(:zlib.gzip("foo bar baz qux"), bad_idea) == :fail
  end
end
