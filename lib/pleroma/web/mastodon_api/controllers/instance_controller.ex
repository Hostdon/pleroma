# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceController do
  use Pleroma.Web, :controller

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:skip_auth when action in [:show, :peers])

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.InstanceOperation

  @doc "GET /api/v1/instance"
  def show(%{assigns: %{user: for_user}} = conn, _params) do
    render(conn, "show.json", for: for_user)
  end

  @doc "GET /api/v1/instance/peers"
  def peers(conn, _params) do
    json(conn, Pleroma.Stats.get_peers())
  end

  @doc "GET /api/v1/instance/translation_languages"
  def translation_languages(conn, _params) do
    with {:ok, source_languages, destination_languages} <- Pleroma.Akkoma.Translator.languages() do
      conn
      |> render("translation_languages.json", %{
        source_languages: source_languages,
        destination_languages: destination_languages
      })
    else
      {:enabled, false} -> json(conn, %{})
      e -> {:error, e}
    end
  end
end
