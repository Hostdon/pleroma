defmodule Pleroma.Web.ApiSpec.FrontendSettingsOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  import Pleroma.Web.ApiSpec.Helpers

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec list_profiles_operation() :: Operation.t()
  def list_profiles_operation() do
    %Operation{
      tags: ["Retrieve frontend setting profiles"],
      summary: "Frontend Settings Profiles",
      description: "List frontend setting profiles",
      operationId: "AkkomaAPI.FrontendSettingsController.list_profiles",
      parameters: [frontend_name_param()],
      security: [%{"oAuth" => ["read:accounts"]}],
      responses: %{
        200 =>
          Operation.response("Profiles", "application/json", %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                name: %Schema{type: :string},
                version: %Schema{type: :integer}
              }
            }
          })
      }
    }
  end

  @spec get_profile_operation() :: Operation.t()
  def get_profile_operation() do
    %Operation{
      tags: ["Retrieve frontend setting profile"],
      summary: "Frontend Settings Profile",
      description: "Get frontend setting profile",
      operationId: "AkkomaAPI.FrontendSettingsController.get_profile",
      security: [%{"oAuth" => ["read:accounts"]}],
      parameters: [frontend_name_param(), profile_name_param()],
      responses: %{
        200 =>
          Operation.response("Profile", "application/json", %Schema{
            type: :object,
            properties: %{
              "version" => %Schema{type: :integer},
              "settings" => %Schema{type: :object, additionalProperties: true}
            }
          }),
        404 => Operation.response("Not Found", "application/json", %Schema{type: :object})
      }
    }
  end

  @spec delete_profile_operation() :: Operation.t()
  def delete_profile_operation() do
    %Operation{
      tags: ["Delete frontend setting profile"],
      summary: "Delete frontend Settings Profile",
      description: "Delete  frontend setting profile",
      operationId: "AkkomaAPI.FrontendSettingsController.delete_profile",
      security: [%{"oAuth" => ["write:accounts"]}],
      parameters: [frontend_name_param(), profile_name_param()],
      responses: %{
        200 => Operation.response("Empty", "application/json", %Schema{type: :object}),
        404 => Operation.response("Not Found", "application/json", %Schema{type: :object})
      }
    }
  end

  @spec update_profile_operation() :: Operation.t()
  def update_profile_operation() do
    %Operation{
      tags: ["Update frontend setting profile"],
      summary: "Frontend Settings Profile",
      description: "Update frontend setting profile",
      operationId: "AkkomaAPI.FrontendSettingsController.update_profile_operation",
      security: [%{"oAuth" => ["write:accounts"]}],
      parameters: [frontend_name_param(), profile_name_param()],
      requestBody: profile_body_param(),
      responses: %{
        200 => Operation.response("Settings", "application/json", %Schema{type: :object}),
        422 => Operation.response("Invalid", "application/json", %Schema{type: :object})
      }
    }
  end

  def frontend_name_param do
    Operation.parameter(:frontend_name, :path, :string, "Frontend name",
      example: "pleroma-fe",
      required: true
    )
  end

  def profile_name_param do
    Operation.parameter(:profile_name, :path, :string, "Profile name",
      example: "mobile",
      required: true
    )
  end

  def profile_body_param do
    request_body(
      "Settings",
      %Schema{
        title: "Frontend Setting Profile",
        type: :object,
        required: [:version, :settings],
        properties: %{
          version: %Schema{
            type: :integer,
            description: "Version of the profile, must increment by 1 each time",
            example: 1
          },
          settings: %Schema{
            type: :object,
            description: "Settings of the profile",
            example: %{
              theme: "dark",
              locale: "en"
            }
          }
        }
      },
      required: true
    )
  end
end
