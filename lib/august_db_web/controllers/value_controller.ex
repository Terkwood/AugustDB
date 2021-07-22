defmodule AugustDbWeb.ValueController do
  use AugustDbWeb, :controller

  @doc """
  e.g.
  ```sh
  curl http://localhost:4000/api/values/1
  ```
  """
  def show(_conn, %{"id" => _key}) do
    raise "todo"
  end

  @doc """
  e.g.
  ```sh
  curl -X PUT  -d value='meh meh'  http://localhost:4000/api/values/1
  ```
  """
  def update(_conn, %{"id" => _key, "value" => _value}) do
    raise "todo"
  end
end
