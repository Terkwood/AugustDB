defmodule AugustDbWeb.ValueController do
  use AugustDbWeb, :controller

  @doc """
  e.g.
  ```sh
  curl http://localhost:4000/api/values/1
  ```
  """
  def show(conn, %{"id" => key}) do
    case Memtable.query(key) do
      {:value, data, _time} when is_binary(data) -> render(conn, "show.json", %{value: data})
      {:value, _data, _time} -> send_resp(conn, 422, "Binary data cannot be displayed")
      _ -> send_resp(conn, 404, "")
    end
  end

  @doc """
  e.g.
  ```sh
  curl -X PUT  -d value='meh meh'  http://localhost:4000/api/values/1
  ```
  """
  def update(conn, %{"id" => key, "value" => value})
      when is_binary(key) and is_binary(value) do
    Memtable.update(key, value)

    send_resp(conn, 204, "")
  end

  @doc """
  e.g.
  ```sh
  curl  -X DELETE http://localhost:4000/api/values/1
  ```
  """
  def delete(conn, %{"id" => key}) do
    Memtable.delete(key)

    send_resp(conn, 204, "")
  end
end
