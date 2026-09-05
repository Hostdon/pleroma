# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.MappedSignatureToIdentityPlug do
  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Utils

  import Plug.Conn
  require Logger

  def init(options), do: options

  def call(%{assigns: %{user: %User{}}} = conn, _opts), do: conn

  # if this has payload make sure it is signed by the same actor that made it
  def call(
        %{
          assigns: %{valid_signature: true, signature_user: signature_user},
          params: %{"actor" => actor}
        } = conn,
        _opts
      ) do
    with actor_id <- Utils.get_ap_id(actor),
         {:federate, true} <- {:federate, should_federate?(signature_user)},
         {:user_match, true} <- {:user_match, signature_user.ap_id == actor_id} do
      conn
      |> assign(:user, signature_user)
      |> AuthHelper.skip_oauth()
    else
      {:user_match, false} ->
        Logger.debug("Failed to map identity from signature (payload actor mismatch)")

        Logger.debug(
          "key_user=#{signature_user.id}(#{signature_user.ap_id}), actor=#{inspect(actor)}"
        )

        assign(conn, :valid_signature, false)

      error ->
        handle_common_errors(conn, actor, signature_user, error)
    end
  end

  # no payload, probably a signed fetch
  def call(%{assigns: %{valid_signature: true, signature_user: signature_user}} = conn, _opts) do
    with {:federate, true} <- {:federate, should_federate?(signature_user)} do
      conn
      |> assign(:user, signature_user)
      |> AuthHelper.skip_oauth()
    else
      error -> handle_common_errors(conn, nil, signature_user, error)
    end
  end

  # supposedly valid signature but no user (this isn’t supposed to happen)
  def call(%{assigns: %{valid_signature: true}} = conn, _opts),
    do: assign(conn, :valid_signature, false)

  # no signature at all
  def call(conn, _opts), do: conn

  def handle_common_errors(conn, actor, signature_user, error) do
    actor_str = if actor == nil, do: "", else: " actor=#{inspect(actor)}"

    case error do
      {:federate, false} ->
        Logger.debug("Identity from signature is instance blocked")
        Logger.debug("key_user=#{signature_user.nickname}(#{signature_user.id})#{actor_str}")
        assign(conn, :valid_signature, false)
    end
  end

  defp should_federate?(%User{ap_id: ap_id}), do: should_federate?(ap_id)

  defp should_federate?(ap_id) do
    if Pleroma.Config.get([:activitypub, :authorized_fetch_mode], false) do
      Pleroma.Web.ActivityPub.Publisher.should_federate?(ap_id)
    else
      true
    end
  end
end
