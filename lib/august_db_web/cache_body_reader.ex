defmodule AugustDbWeb.CacheBodyReader do
  @moduledoc """
  Thanks to https://github.com/phoenixframework/phoenix/issues/459#issuecomment-440820663
  For this solution
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    body = [body | conn.private[:raw_body] || []]
    conn = Plug.Conn.put_private(conn, :raw_body, body)
    {:ok, body, conn}
  end

  def read_cached_body(conn) do
    conn.private[:raw_body]
  end
end
