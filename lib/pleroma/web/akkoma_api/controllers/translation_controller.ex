defmodule Pleroma.Web.AkkomaAPI.TranslationController do
  use Pleroma.Web, :controller

  alias Pleroma.Akkoma.Translator
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  require Logger

  @unauthenticated_access %{fallback: :proceed_unauthenticated, scopes: []}
  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:statuses"]}
    when action in [
           :languages
         ]
  )

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.TranslationOperation

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc "GET /api/v1/akkoma/translation/languages"
  def languages(conn, _params) do
    with {:enabled, true} <- {:enabled, Pleroma.Config.get([:translator, :enabled])},
         {:ok, source_languages, dest_languages} <- Translator.languages() do
      conn
      |> json(%{source: source_languages, target: dest_languages})
    else
      {:enabled, false} ->
        json(conn, %{})

      e ->
        Logger.error("Translation language list error: #{inspect(e)}")
        {:error, e}
    end
  end
end
