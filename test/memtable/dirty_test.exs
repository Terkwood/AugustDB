defmodule DirtyMemtableTest do
  use ExUnit.Case, async: true

  test "dirty memtable stub" do
    resource = Memtable.Dirty.new()
    Memtable.Dirty.update(resource, 4)
    assert Memtable.Dirty.query(resource) == 5
  end
end
