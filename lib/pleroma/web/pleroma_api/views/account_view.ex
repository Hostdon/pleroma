# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AccountView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI

  def render(view, opts), do: MastodonAPI.AccountView.render(view, opts)
end
