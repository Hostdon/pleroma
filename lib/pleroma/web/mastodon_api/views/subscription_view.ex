# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SubscriptionView do
  use Pleroma.Web, :view
  alias Pleroma.Web.Push

  def render("show.json", %{subscription: subscription}) do
    %{
      id: to_string(subscription.id),
      endpoint: subscription.endpoint,
      alerts: Map.get(subscription.data, "alerts"),
      server_key: server_key()
    }
  end

  defp server_key, do: Keyword.get(Push.vapid_config(), :public_key)
end
