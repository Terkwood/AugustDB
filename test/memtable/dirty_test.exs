defmodule DirtyMemtableTest do
  use ExUnit.Case, async: true

  test "dirty memtable stub" do
    resource = Memtable.Dirty.new()
    Memtable.Dirty.update(resource, "foo", "bar")
    assert Memtable.Dirty.query(resource, "foo") == "bar"

    assert Task.await(
             Task.async(fn ->
               Memtable.Dirty.update(resource, "foo", "qux")
               Memtable.Dirty.query(resource, "foo")
             end)
           ) == "qux"

    assert Memtable.Dirty.query(resource, "foo") == "qux"
  end
end
