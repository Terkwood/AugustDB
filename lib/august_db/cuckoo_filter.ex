defmodule CuckooFilter do
  @moduledoc """
  Using SSTables, it takes a long time to determine that a certain
  record does not exist. In the case where there is neither a value
  nor a tombstone associated with a key, you need to read through all
  SSTables before you can return a negative result.

  You can use a bloom or cuckoo filter to speed up queries for kv pairs
  which don't exist. These probabilistic data structures allow you to
  (mostly) determine set membership.

  When the set membership test returns false, you can rely on the result.
  The K/V pair definitely does not exist.

  When the set membership test returns true, there's a possibility that
  it's a false positive -- it may not be in the given table.
  """
end
