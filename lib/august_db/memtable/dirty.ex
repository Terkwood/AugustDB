defmodule Memtable.Dirty do
  @moduledoc """
  These function stubs will be overridden when the NIF is loaded
  """
  use Rustler,
    otp_app: :august_db,
    crate: :dirty_memtable

  def new(), do: :erlang.nif_error(:nif_not_loaded)
  def query(_resource, _key), do: :erlang.nif_error(:nif_not_loaded)
  def update(_resource, _key, _value), do: :erlang.nif_error(:nif_not_loaded)
  def delete(_resource, _key), do: :erlang.nif_error(:nif_not_loaded)
end
