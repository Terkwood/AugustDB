defmodule AugustDbWeb.ValueView do
  use AugustDbWeb, :view

  def render("update.json", %{key: key, value: value}) do
    %{key: key, value: value}
  end
end
