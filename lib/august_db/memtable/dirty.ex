defmodule Memtable.Dirty do
  @moduledoc """
  Shared Red Black tree which can be mutated inside any erl/elixir process.
  Access in managed via a ResourceArc
  https://docs.rs/rustler/0.22.0/rustler/resource/struct.ResourceArc.html
  """
  use Rustler,
    otp_app: :august_db,
    crate: :dirty_memtable

  def query(_key), do: :erlang.nif_error(:nif_not_loaded)
  def update(_key, _value), do: :erlang.nif_error(:nif_not_loaded)
  def delete(_key), do: :erlang.nif_error(:nif_not_loaded)
  def prepare_flush(), do: :erlang.nif_error(:nif_not_loaded)
end
