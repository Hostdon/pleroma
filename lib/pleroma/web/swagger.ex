defmodule Pleroma.Web.Swagger do
  alias Pleroma.Config

  def ui_enabled? do
    Config.get([:frontends, :swagger, "enabled"])
  end
end
