defmodule Pleroma.Web.Pipelines do
  def common do
    quote do
      pipeline :accepts_html do
        plug(:accepts, ["html"])
      end

      pipeline :accepts_html_xml do
        plug(:accepts, ["html", "xml", "rss", "atom"])
      end

      pipeline :accepts_html_json do
        plug(:accepts, ["html", "activity+json", "json"])
      end

      pipeline :accepts_html_xml_json do
        plug(:accepts, ["html", "xml", "rss", "atom", "activity+json", "json"])
      end

      pipeline :accepts_xml_rss_atom do
        plug(:accepts, ["xml", "rss", "atom"])
      end

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:fetch_session)
      end

      pipeline :oauth do
        plug(:fetch_session)
        plug(Pleroma.Web.Plugs.OAuthPlug)
        plug(Pleroma.Web.Plugs.UserEnabledPlug)
        plug(Pleroma.Web.Plugs.EnsureUserTokenAssignsPlug)
      end

      # Note: expects _user_ authentication (user-unbound app-bound tokens don't   qualify)
      pipeline :expect_user_authentication do
        plug(Pleroma.Web.Plugs.ExpectAuthenticatedCheckPlug)
      end

      # Note: expects public instance or _user_ authentication (user-unbound tok  ens don't qualify)
      pipeline :expect_public_instance_or_user_authentication do
        plug(Pleroma.Web.Plugs.ExpectPublicOrAuthenticatedCheckPlug)
      end

      pipeline :authenticate do
        plug(Pleroma.Web.Plugs.OAuthPlug)
        plug(Pleroma.Web.Plugs.BasicAuthDecoderPlug)
        plug(Pleroma.Web.Plugs.UserFetcherPlug)
        plug(Pleroma.Web.Plugs.AuthenticationPlug)
      end

      pipeline :after_auth do
        plug(Pleroma.Web.Plugs.UserEnabledPlug)
        plug(Pleroma.Web.Plugs.SetUserSessionIdPlug)
        plug(Pleroma.Web.Plugs.EnsureUserTokenAssignsPlug)
        plug(Pleroma.Web.Plugs.UserTrackingPlug)
      end

      pipeline :base_api do
        plug(:accepts, ["json"])
        plug(:fetch_session)
        plug(:authenticate)
        plug(OpenApiSpex.Plug.PutApiSpec, module: Pleroma.Web.ApiSpec)
      end

      pipeline :no_auth_or_privacy_expectations_api do
        plug(:base_api)
        plug(:after_auth)
        plug(Pleroma.Web.Plugs.IdempotencyPlug)
      end

      # Pipeline for app-related endpoints (no user auth checks — app-bound toke  ns must be supported)
      pipeline :app_api do
        plug(:no_auth_or_privacy_expectations_api)
      end

      pipeline :api do
        plug(:expect_public_instance_or_user_authentication)
        plug(:no_auth_or_privacy_expectations_api)
      end

      pipeline :authenticated_api do
        plug(:expect_user_authentication)
        plug(:no_auth_or_privacy_expectations_api)
        plug(Pleroma.Web.Plugs.EnsureAuthenticatedPlug)
      end

      pipeline :admin_api do
        plug(:expect_user_authentication)
        plug(:base_api)
        plug(Pleroma.Web.Plugs.AdminSecretAuthenticationPlug)
        plug(:after_auth)
        plug(Pleroma.Web.Plugs.EnsureAuthenticatedPlug)
        plug(Pleroma.Web.Plugs.UserIsStaffPlug)
        plug(Pleroma.Web.Plugs.IdempotencyPlug)
      end

      pipeline :require_privileged_staff do
        plug(Pleroma.Web.Plugs.EnsureStaffPrivilegedPlug)
      end

      pipeline :require_admin do
        plug(Pleroma.Web.Plugs.UserIsAdminPlug)
      end

      pipeline :pleroma_html do
        plug(:browser)
        plug(:authenticate)
        plug(Pleroma.Web.Plugs.EnsureUserTokenAssignsPlug)
      end

      pipeline :well_known do
        plug(:accepts, ["json", "jrd+json", "xml", "xrd+xml"])
      end

      pipeline :config do
        plug(:accepts, ["json", "xml"])
        plug(OpenApiSpex.Plug.PutApiSpec, module: Pleroma.Web.ApiSpec)
      end

      pipeline :pleroma_api do
        plug(:accepts, ["html", "json"])
        plug(OpenApiSpex.Plug.PutApiSpec, module: Pleroma.Web.ApiSpec)
      end

      pipeline :mailbox_preview do
        plug(:accepts, ["html"])

        plug(:put_secure_browser_headers, %{
          "content-security-policy" =>
            "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' 'unsafe-eval'"
        })
      end

      pipeline :http_signature do
        plug(Pleroma.Web.Plugs.HTTPSignaturePlug)
        plug(Pleroma.Web.Plugs.MappedSignatureToIdentityPlug)
      end

      pipeline :static_fe do
        plug(Pleroma.Web.Plugs.StaticFEPlug)
      end
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
