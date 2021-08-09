defmodule NifNotLoadedError do
  defexception message: "nif not loaded"
end

defmodule Memtable.Dirty do
  @moduledoc """
  These function stubs will be overridden when the NIF is loaded
  """
  use Rustler,
    otp_app: :august_db,
    crate: :dirty_memtable

  defp err do
    throw()
  end

  def create(), do: err()
end
