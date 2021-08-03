defmodule AugustDbWeb.ValueView do
  use AugustDbWeb, :view
  alias AugustDbWeb.ValueView

  def render("show.json", %{value: data}) do
    render_one(data, ValueView, "value.json")
  end

  def render("value.json", %{value: data}) do
    data
  end

  def render("update.json", %{key: key, value: value}) do
    %{key: key, value: value}
  end
end
