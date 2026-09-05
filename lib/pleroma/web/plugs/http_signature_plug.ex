# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]

  alias HTTPSignatures.HTTPKey

  use Pleroma.Web, :verified_routes
  alias Pleroma.Activity
  require Logger

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  # ensure host check is run before this without mixing the two up here
  def call(%{assigns: %{host_matches: true}} = conn, _opts) do
    if get_format(conn) in ["json", "activity+json"] do
      conn
      |> maybe_assign_valid_signature()
    else
      conn
    end
  end

  def call(conn, _opts), do: conn

  def route_aliases(%{path_info: ["objects", id], query_string: query_string, method: method}) do
    ap_id = url(~p[/objects/#{id}])
    method = String.downcase(method)

    [
      fn ->
        with %Activity{} = activity <- Activity.get_by_object_ap_id_with_object(ap_id) do
          with_and_without_query(
            "#{method} /notice/#{activity.id}",
            query_string
          )
        else
          _ -> []
        end
      end
    ]
  end

  def route_aliases(_), do: []

  defp maybe_log_error(conn, verification_error) do
    siginfo_str =
      "<#{conn.method} #{conn.request_path}> #{inspect(get_req_header(conn, "signature"))}"

    case verification_error do
      :gone ->
        # We can't verify the data since the actor was deleted and not previously known.
        # Likely we just received the actor’s Delete activity, so just silently drop.
        Logger.debug(
          "Unable to verify request signature of deleted actor; dropping (#{siginfo_str})"
        )

      {:reject, reason} ->
        Logger.debug(
          "Refusing to validate signature from rejected key due to #{inspect(reason)} #{siginfo_str}"
        )

      :wrong_signature ->
        Logger.warning("Received request with invalid signature!\n#{inspect(conn)}")

      {:fetch_key, e} ->
        Logger.info(
          "Unable to verify request since key cannot be retrieved: #{inspect(e)} #{siginfo_str}"
        )

      error ->
        Logger.error(
          "Failed to verify request signature due to fatal error: #{inspect(error)} #{inspect(conn)}"
        )
    end

    conn
  end

  defp maybe_halt(conn, :gone) do
    # If the key was deleted the error is basically unrecoverable.
    # Most likely it was the Delete activity for the key actor and we never knew about this actor before.
    # Older Mastodon is very insistent about resending those Deletes until it receives a success.
    # see: https://github.com/mastodon/mastodon/pull/33617
    with "POST" <- conn.method,
         %{"type" => "Delete"} <- conn.body_params do
      conn
      |> resp(202, "Accepted")
      |> halt()
    else
      _ -> conn
    end
  end

  defp maybe_halt(conn, {:reject, _}) do
    cond do
      conn.method == "POST" ->
        conn
        |> resp(202, "Accepted")
        |> halt()

      true ->
        conn
        |> resp(404, "Not found")
        |> halt()
    end
  end

  defp maybe_halt(conn, _), do: conn

  defp assign_valid_signature(%{assigns: %{valid_signature: true}} = conn, _),
    do: conn

  defp assign_valid_signature(conn, request_targets) do
    case HTTPSignatures.validate_conn(conn, request_targets) do
      {:ok, %HTTPKey{user_data: ud}} ->
        conn
        |> assign(:valid_signature, true)
        |> assign(:signature_user, ud["key_user"])

      {:error, e} ->
        conn
        |> assign(:valid_signature, false)
        |> assign(:signature_user, nil)
        |> maybe_log_error(e)
        |> maybe_halt(e)
    end
  end

  defp maybe_assign_valid_signature(conn) do
    if has_signature_header?(conn) do
      # set (request-target) header to the appropriate value
      # we also replace the digest header with the one we computed
      method = String.downcase(conn.method)

      request_targets =
        with_and_without_query(
          "#{method} " <> conn.request_path,
          conn.query_string
        ) ++ route_aliases(conn)

      conn =
        case conn do
          %{assigns: %{digest: digest}} = conn -> put_req_header(conn, "digest", digest)
          conn -> conn
        end

      assign_valid_signature(conn, request_targets)
    else
      Logger.debug("No signature header!")
      conn
    end
  end

  defp has_signature_header?(conn) do
    conn |> get_req_header("signature") |> Enum.at(0, false)
  end

  defp with_and_without_query(base_target, query) when is_binary(query),
    do: [base_target <> "?" <> query, base_target]

  defp with_and_without_query(base_target, _), do: [base_target]
end
