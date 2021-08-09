defmodule DirtyMemtableTest do
  use ExUnit.Case, async: true

  test "dirty memtable stub" do
    resource = Memtable.Dirty.new()
    Memtable.Dirty.update(resource, "foo", "bar")
    assert Memtable.Dirty.query(resource, "foo") == {:value, "bar"}

    assert Task.await(
             Task.async(fn ->
               Memtable.Dirty.update(resource, "foo", "qux")
               Memtable.Dirty.query(resource, "foo")
             end)
           ) == {:value, "qux"}

    assert Memtable.Dirty.query(resource, "foo") == {:value, "qux"}
  end

  test "delete creates tombstone" do
    resource = Memtable.Dirty.new()
    Memtable.Dirty.delete(resource, "foo")
    assert Memtable.Dirty.query(resource, "foo") == {:tombstone, ""}
  end

  test "query non-existent" do
    resource = Memtable.Dirty.new()
    assert Memtable.Dirty.query(resource, "nothing") == {:none, ""}
  end
end
