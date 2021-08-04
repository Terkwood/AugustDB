defmodule SSTable.Index do
  use Agent

  @bytes_per_entry 4 * 1024
  @doc """
  Defines how sparse the index file should be.
  The application will only write one `key -> offset`
  value per this many bytes.
  """
  def bytes_per_entry do
    @bytes_per_entry
  end
end
