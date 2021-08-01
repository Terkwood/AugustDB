defmodule SSTable.Compaction do
  @moduledoc """
  SSTable Compaction
  """

  @doc """
  Run compaction on all SSTables, generating an SST and an IDX file
  """
  def run do
    old_sst_paths = Enum.sort(Path.wildcard("*.sst"))

    case merge(old_sst_paths) do
      :noop ->
        :noop

      new_sst_idx ->
        for p <- old_sst_paths do
          File.rm!(p)
          File.rm!(hd(String.split(p, ".sst")) <> ".idx")
        end

        new_sst_idx
    end
  end

  defp merge(many_paths) when is_list(many_paths) do
    time_name = :erlang.system_time()
    output_path = "#{time_name}.sst"

    many_devices =
      Enum.map(many_paths, fn p ->
        {:ok, f} = :file.open(p, [:read, :raw])
        f
      end)

    {:ok, output_sst} = :file.open(output_path, [:raw, :append])

    raise "todo"
  end
end
