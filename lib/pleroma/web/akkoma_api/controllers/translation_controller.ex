defmodule Pleroma.Web.AkkomaAPI.TranslationController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Plugs.OAuthScopesPlug

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

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
    with {:ok, source_languages, dest_languages} <- get_languages() do
      conn
      |> json(%{source: source_languages, target: dest_languages})
    else
      e -> IO.inspect(e)
    end
  end

  defp get_languages do
    module = Pleroma.Config.get([:translator, :module])

    @cachex.fetch!(:translations_cache, "languages:#{module}}", fn _ ->
      with {:ok, source_languages, dest_languages} <- module.languages() do
        {:ok, source_languages, dest_languages}
      else
        {:error, err} -> {:ignore, {:error, err}}
      end
    end)
  end
end
