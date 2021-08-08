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
      {:value, data, _time} when is_binary(data) ->
        render(conn, "show.json", %{value: data})

      {:value, _data, _time} ->
        send_422(conn)

      {:tombstone, _time} ->
        send_404(conn)

      :none ->
        case SSTable.query(key, CuckooFilter.eliminate(key)) do
          :tombstone ->
            send_404(conn)

          :none ->
            send_404(conn)

          value when is_binary(value) ->
            render(conn, "show.json", %{value: value})
        end
    end
  end

  defp send_404(conn) do
    send_resp(conn, 404, "")
  end

  defp send_422(conn) do
    send_resp(conn, 422, "Binary data cannot be displayed")
  end

  @doc """
  # Update as form data or as JSON object

  You can put this as form data
  ```sh
  curl -X PUT  -d value='meh meh'  http://localhost:4000/api/values/1
  ```

  You can also put this as a JSON object
  ```
  curl -X PUT  -d '{"value":"meh meh"}'  http://localhost:4000/api/values/1
  ```

  # Update using application/json with a simple string

  The body needs to be a JSON string, thus it needs to have the
  double quotes (in addition to the single quotes for curl). 🥺

  ```sh
  curl -X PUT -H 'Content-Type: application/json' -d '"meh meh"' http://localhost:4000/api/values/1
  ```
  """
  def update(conn, %{"id" => key, "value" => value})
      when is_binary(key) and is_binary(value) do
    update_kv(conn, key, value)
  end

  def update(conn, %{"id" => key, "_json" => value}) when is_binary(value) and is_binary(key) do
    update_kv(conn, key, value)
  end

  defp update_kv(conn, key, value) do
    CommitLog.append(key, value)

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
    CommitLog.append(key, :tombstone)

    Memtable.delete(key)

    send_resp(conn, 204, "")
  end
end
