defmodule Pleroma.Web.AkkomaAPI.FrontendSettingsController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Akkoma.FrontendSettingsProfile

  @unauthenticated_access %{fallback: :proceed_unauthenticated, scopes: []}
  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["read:accounts"]}
    when action in [
           :list_profiles,
           :get_profile
         ]
  )

  plug(
    OAuthScopesPlug,
    %{@unauthenticated_access | scopes: ["write:accounts"]}
    when action in [
           :update_profile,
           :delete_profile
         ]
  )

  plug(Pleroma.Web.ApiSpec.CastAndValidate)
  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.FrontendSettingsOperation

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  @doc "GET /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name"
  def get_profile(conn, %{frontend_name: frontend_name, profile_name: profile_name}) do
    with %FrontendSettingsProfile{} = profile <-
           FrontendSettingsProfile.get_by_user_and_frontend_name_and_profile_name(
             conn.assigns.user,
             frontend_name,
             profile_name
           ) do
      conn
      |> json(%{
        settings: profile.settings,
        version: profile.version
      })
    else
      nil -> {:error, :not_found}
    end
  end

  @doc "GET /api/v1/akkoma/frontend_settings/:frontend_name"
  def list_profiles(conn, %{frontend_name: frontend_name}) do
    with profiles <-
           FrontendSettingsProfile.get_all_by_user_and_frontend_name(
             conn.assigns.user,
             frontend_name
           ),
         data <-
           Enum.map(profiles, fn profile ->
             %{name: profile.profile_name, version: profile.version}
           end) do
      json(conn, data)
    end
  end

  @doc "DELETE /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name"
  def delete_profile(conn, %{frontend_name: frontend_name, profile_name: profile_name}) do
    with %FrontendSettingsProfile{} = profile <-
           FrontendSettingsProfile.get_by_user_and_frontend_name_and_profile_name(
             conn.assigns.user,
             frontend_name,
             profile_name
           ),
         {:ok, _} <- FrontendSettingsProfile.delete_profile(profile) do
      json(conn, %{deleted: "ok"})
    else
      nil -> {:error, :not_found}
    end
  end

  @doc "PUT /api/v1/akkoma/frontend_settings/:frontend_name/:profile_name"
  def update_profile(%{body_params: %{settings: settings, version: version}} = conn, %{
        frontend_name: frontend_name,
        profile_name: profile_name
      }) do
    with {:ok, profile} <-
           FrontendSettingsProfile.create_or_update(
             conn.assigns.user,
             frontend_name,
             profile_name,
             settings,
             version
           ) do
      conn
      |> json(profile.settings)
    end
  end
end
