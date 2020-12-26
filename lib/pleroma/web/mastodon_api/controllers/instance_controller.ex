# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceController do
  use Pleroma.Web, :controller

  plug(OpenApiSpex.Plug.CastAndValidate)

  plug(
    :skip_plug,
    [Pleroma.Web.Plugs.OAuthScopesPlug, Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug]
    when action in [:show, :peers]
  )

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.InstanceOperation

  @doc "GET /api/v1/instance"
  def show(conn, _params) do
    render(conn, "show.json")
  end

  @doc "GET /api/v1/instance/peers"
  def peers(conn, _params) do
    json(conn, Pleroma.Stats.get_peers())
  end
end
