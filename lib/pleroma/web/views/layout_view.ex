# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.LayoutView do
  use Pleroma.Web, :view
  import Phoenix.HTML

  def render_html(file) do
    case :httpc.request(Pleroma.Web.Endpoint.url() <> file) do
      {:ok, {{_, 200, _}, _headers, body}} -> body
    end
  end
end
