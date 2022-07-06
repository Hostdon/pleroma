defmodule Pleroma.Web.Metadata.Providers.Theme do
  alias Pleroma.Web.Metadata.Providers.Provider

  @behaviour Provider

  @impl Provider
  def build_tags(_) do
    [
      {:meta,
       [
         name: "theme-color",
         content: Pleroma.Config.get([__MODULE__, :theme_color])
       ], []}
    ]
  end
end
