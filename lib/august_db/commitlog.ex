defmodule CommitLog do
  # @tombstone_string Tombstone.string()
  @log_file "commit.log"

  # def append(key, :tombstone) do
  #  __MODULE__.append(key, @tombstone_string)
  # end

  def append(key, value) do
    File.write!(@log_file, key <> "\t" <> value <> "\n", :append)
  end
end
