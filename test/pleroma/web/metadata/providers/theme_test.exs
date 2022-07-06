defmodule Pleroma.Web.Metadata.Providers.ThemeTest do
  use Pleroma.DataCase
  alias Pleroma.Web.Metadata.Providers.Theme

  setup do: clear_config([Pleroma.Web.Metadata.Providers.Theme, :theme_color], "configured")

  test "it renders the theme-color meta tag" do
    result = Theme.build_tags(%{})

    assert {:meta, [name: "theme-color", content: "configured"], []} in result
  end
end
