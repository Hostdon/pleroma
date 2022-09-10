# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1, text: 2]
  alias Pleroma.Activity
  alias Pleroma.Web.Router
  require Logger

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    if get_format(conn) == "activity+json" do
      conn
      |> maybe_assign_valid_signature()
      |> maybe_require_signature()
    else
      conn
    end
  end

  def route_aliases(%{path_info: ["objects", id], query_string: query_string}) do
    ap_id = Router.Helpers.o_status_url(Pleroma.Web.Endpoint, :object, id)

    with %Activity{} = activity <- Activity.get_by_object_ap_id_with_object(ap_id) do
      ["/notice/#{activity.id}", "/notice/#{activity.id}?#{query_string}"]
    else
      _ -> []
    end
  end

  def route_aliases(_), do: []

  defp assign_valid_signature_on_route_aliases(conn, []), do: conn

  defp assign_valid_signature_on_route_aliases(%{assigns: %{valid_signature: true}} = conn, _),
    do: conn

  defp assign_valid_signature_on_route_aliases(conn, [path | rest]) do
    request_target = String.downcase("#{conn.method}") <> " #{path}"

    conn =
      conn
      |> put_req_header("(request-target)", request_target)
      |> case do
        %{assigns: %{digest: digest}} = conn -> put_req_header(conn, "digest", digest)
        conn -> conn
      end

    conn
    |> assign(:valid_signature, HTTPSignatures.validate_conn(conn))
    |> assign_valid_signature_on_route_aliases(rest)
  end

  defp maybe_assign_valid_signature(conn) do
    if has_signature_header?(conn) do
      # set (request-target) header to the appropriate value
      # we also replace the digest header with the one we computed
      possible_paths =
        route_aliases(conn) ++ [conn.request_path, conn.request_path <> "?#{conn.query_string}"]

      assign_valid_signature_on_route_aliases(conn, possible_paths)
    else
      Logger.debug("No signature header!")
      conn
    end
  end

  defp has_signature_header?(conn) do
    conn |> get_req_header("signature") |> Enum.at(0, false)
  end

  defp maybe_require_signature(%{assigns: %{valid_signature: true}} = conn), do: conn

  defp maybe_require_signature(conn) do
    if Pleroma.Config.get([:activitypub, :authorized_fetch_mode], false) do
      conn
      |> put_status(:unauthorized)
      |> text("Request not signed")
      |> halt()
    else
      conn
    end
  end
end
