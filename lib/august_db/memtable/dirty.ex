defmodule Memtable.Dirty do
  @moduledoc """
  Shared Red Black tree which can be mutated inside any erl/elixir process.
  Access in managed via a ResourceArc
  https://docs.rs/rustler/0.22.0/rustler/resource/struct.ResourceArc.html
  """
  use Rustler,
    otp_app: :august_db,
    crate: :dirty_memtable

  def new(), do: :erlang.nif_error(:nif_not_loaded)
  def query(_resource, _key), do: :erlang.nif_error(:nif_not_loaded)
  def update(_resource, _key, _value), do: :erlang.nif_error(:nif_not_loaded)
  def delete(_resource, _key), do: :erlang.nif_error(:nif_not_loaded)
  def to_list(_resource), do: :erlang.nif_error(:nif_not_loaded)
  def keys(_resource), do: :erlang.nif_error(:nif_not_loaded)
end
