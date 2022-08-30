defmodule Pleroma.Web.ApiSpec.TranslationOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema

  @spec open_api_operation(atom) :: Operation.t()
  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  @spec languages_operation() :: Operation.t()
  def languages_operation() do
    %Operation{
      tags: ["Retrieve status translation"],
      summary: "Translate status",
      description: "View the translation of a given status",
      operationId: "AkkomaAPI.TranslationController.languages",
      security: [%{"oAuth" => ["read:statuses"]}],
      responses: %{
        200 => Operation.response("Translation", "application/json", languages_schema())
      }
    }
  end

  defp languages_schema do
    %Schema{
      type: "array",
      items: %Schema{
        type: "object",
        properties: %{
          code: %Schema{
            type: "string"
          },
          name: %Schema{
            type: "string"
          }
        }
      }
    }
  end
end
