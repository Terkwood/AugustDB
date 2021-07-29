defmodule CommitLog do
  def append(_key, :tombstone) do
    raise "todo"
  end

  def append(_key, _value) do
    raise "todo"
  end
end
