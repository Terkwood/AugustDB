defmodule AugustDbWeb.ValueView do
  use AugustDbWeb, :view

  def render("show.json", value) when is_binary(value) do
    value
  end

  def render("update.json", %{key: key, value: value}) do
    %{key: key, value: value}
  end
end
