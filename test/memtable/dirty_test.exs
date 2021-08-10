defmodule DirtyMemtableTest do
  use ExUnit.Case, async: true

  test "dirty memtable stub" do
    Memtable.Dirty.update("foo", "bar")
    assert Memtable.Dirty.query("foo") == {:value, "bar"}

    assert Task.await(
             Task.async(fn ->
               Memtable.Dirty.update("foo", "qux")
               Memtable.Dirty.query("foo")
             end)
           ) == {:value, "qux"}

    assert Memtable.Dirty.query("foo") == {:value, "qux"}
  end

  test "delete creates tombstone" do
    Memtable.Dirty.delete("foo")
    assert Memtable.Dirty.query("foo") == {:tombstone, ""}
  end

  test "query non-existent" do
    assert Memtable.Dirty.query("nothing") == {:none, ""}
  end
end
