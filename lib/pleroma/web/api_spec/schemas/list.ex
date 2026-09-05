# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.Schemas.List do
  alias OpenApiSpex.Schema

  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "List",
    description: "Represents a list of users",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "The internal database ID of the list"},
      title: %Schema{type: :string, description: "The user-defined title of the list"},
      exclusive: %Schema{
        type: :boolean,
        description: "Whether members of the list should be removed from the “Home” feed"
      }
    },
    example: %{
      "id" => "12249",
      "title" => "Friends"
    }
  })
end
