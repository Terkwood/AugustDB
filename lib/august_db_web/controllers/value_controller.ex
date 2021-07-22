defmodule AugustDbWeb.ValueController do
  use AugustDbWeb, :controller

  def show(_conn, %{"id" => _key}) do
    raise "todo"
  end

  def update(_conn, %{"id" => _key, "value" => _value}) do
    raise "todo"
  end
end
