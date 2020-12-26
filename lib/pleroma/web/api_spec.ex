# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec do
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.Operation
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Router

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers:
        if Phoenix.Endpoint.server?(:pleroma, Endpoint) do
          [
            # Populate the Server info from a phoenix endpoint
            OpenApiSpex.Server.from_endpoint(Endpoint)
          ]
        else
          []
        end,
      info: %OpenApiSpex.Info{
        title: "Pleroma",
        description: Application.spec(:pleroma, :description) |> to_string(),
        version: Application.spec(:pleroma, :vsn) |> to_string()
      },
      # populate the paths from a phoenix router
      paths: OpenApiSpex.Paths.from_router(Router),
      components: %OpenApiSpex.Components{
        parameters: %{
          "accountIdOrNickname" =>
            Operation.parameter(:id, :path, :string, "Account ID or nickname",
              example: "123",
              required: true
            )
        },
        securitySchemes: %{
          "oAuth" => %OpenApiSpex.SecurityScheme{
            type: "oauth2",
            flows: %OpenApiSpex.OAuthFlows{
              password: %OpenApiSpex.OAuthFlow{
                authorizationUrl: "/oauth/authorize",
                tokenUrl: "/oauth/token",
                scopes: %{
                  "read" => "read",
                  "write" => "write",
                  "follow" => "follow",
                  "push" => "push"
                }
              }
            }
          }
        }
      }
    }
    # discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
