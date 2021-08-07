defmodule ChecksumTest do
  use ExUnit.Case, async: true
  import Checksum

  test "create checksum" do
    chk = create("foo bar baz qux")
    assert chk == <<216, 38, 20, 177>>
  end

  test "verify plain k/v pair positive" do
    chk = create("some_key" <> "some_value")
    assert verify("some_key" <> "some_value", chk) == :ok
  end

  test "verify plain k/v pair negative" do
    chk = create("some_key" <> "some_value")
    assert verify("some_key" <> "some_valu", chk) == :fail
  end

  test "verify gzip checksum positive" do
    chk = create("foo bar baz qux")
    assert verify_gzip(:zlib.gzip("foo bar baz qux"), chk) == :ok
  end

  test "verify checksum negative" do
    bad_idea = <<214, 38, 21, 176>>
    assert verify_gzip(:zlib.gzip("foo bar baz qux"), bad_idea) == :fail
  end
end
