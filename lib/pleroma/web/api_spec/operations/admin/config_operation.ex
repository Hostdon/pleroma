# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Admin.ConfigOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  import Pleroma.Web.ApiSpec.Helpers

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  def show_operation do
    %Operation{
      tags: ["Admin", "Config"],
      summary: "Get list of merged default settings with saved in database",
      operationId: "AdminAPI.ConfigController.show",
      parameters: [
        Operation.parameter(
          :only_db,
          :query,
          %Schema{type: :boolean, default: false},
          "Get only saved in database settings"
        )
        | admin_api_params()
      ],
      security: [%{"oAuth" => ["read"]}],
      responses: %{
        200 => Operation.response("Config", "application/json", config_response()),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def update_operation do
    %Operation{
      tags: ["Admin", "Config"],
      summary: "Update config settings",
      operationId: "AdminAPI.ConfigController.update",
      security: [%{"oAuth" => ["write"]}],
      parameters: admin_api_params(),
      requestBody:
        request_body("Parameters", %Schema{
          type: :object,
          properties: %{
            configs: %Schema{
              type: :array,
              items: %Schema{
                type: :object,
                properties: %{
                  group: %Schema{type: :string},
                  key: %Schema{type: :string},
                  value: any(),
                  delete: %Schema{type: :boolean},
                  subkeys: %Schema{type: :array, items: %Schema{type: :string}}
                }
              }
            }
          }
        }),
      responses: %{
        200 => Operation.response("Config", "application/json", config_response()),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  def descriptions_operation do
    %Operation{
      tags: ["Admin", "Config"],
      summary: "Get JSON with config descriptions.",
      operationId: "AdminAPI.ConfigController.descriptions",
      security: [%{"oAuth" => ["read"]}],
      parameters: admin_api_params(),
      responses: %{
        200 =>
          Operation.response("Config Descriptions", "application/json", %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                group: %Schema{type: :string},
                key: %Schema{type: :string},
                type: %Schema{oneOf: [%Schema{type: :string}, %Schema{type: :array}]},
                description: %Schema{type: :string},
                children: %Schema{
                  type: :array,
                  items: %Schema{
                    type: :object,
                    properties: %{
                      key: %Schema{type: :string},
                      type: %Schema{oneOf: [%Schema{type: :string}, %Schema{type: :array}]},
                      description: %Schema{type: :string},
                      suggestions: %Schema{type: :array}
                    }
                  }
                }
              }
            }
          }),
        400 => Operation.response("Bad Request", "application/json", ApiError)
      }
    }
  end

  defp any do
    %Schema{
      oneOf: [
        %Schema{type: :array},
        %Schema{type: :object},
        %Schema{type: :string},
        %Schema{type: :integer},
        %Schema{type: :boolean}
      ]
    }
  end

  defp config_response do
    %Schema{
      type: :object,
      properties: %{
        configs: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              group: %Schema{type: :string},
              key: %Schema{type: :string},
              value: any()
            }
          }
        },
        need_reboot: %Schema{
          type: :boolean,
          description:
            "If `need_reboot` is `true`, instance must be restarted, so reboot time settings can take effect"
        }
      }
    }
  end
end
