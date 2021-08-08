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
  e.g.
  ```sh
  curl -X PUT  -d value='meh meh'  http://localhost:4000/api/values/1
  ```
  """
  def update(conn, %{"id" => key, "value" => value})
      when is_binary(key) and is_binary(value) do
    start_commitlog_append = :os.system_time()
    CommitLog.append(key, value)
    stop_commitlog_append = :os.system_time()

    start_memtable_update = :os.system_time()
    Memtable.update(key, value)
    stop_memtable_update = :os.system_time()

    commitlog_append_time = stop_commitlog_append - start_commitlog_append
    memtable_update_time = stop_memtable_update - start_memtable_update

    IO.puts(
      "Commitlog append time: #{commitlog_append_time}\tMemtable update time: #{memtable_update_time}"
    )

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
