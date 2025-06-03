# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.HTTPSignaturePlug do
  import Plug.Conn
  import Phoenix.Controller, only: [get_format: 1]

  use Pleroma.Web, :verified_routes
  alias Pleroma.Activity
  alias Pleroma.Instances
  alias Pleroma.User.SigningKey
  require Logger

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def init(options) do
    options
  end

  def call(%{assigns: %{valid_signature: true}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    if get_format(conn) in ["json", "activity+json"] do
      conn
      |> maybe_assign_valid_signature()
      |> maybe_require_signature()
    else
      conn
    end
  end

  def route_aliases(%{path_info: ["objects", id], query_string: query_string}) do
    ap_id = url(~p[/objects/#{id}])

    with %Activity{} = activity <- Activity.get_by_object_ap_id_with_object(ap_id) do
      [~p"/notice/#{activity.id}", "/notice/#{activity.id}?#{query_string}"]
    else
      _ -> []
    end
  end

  def route_aliases(_), do: []

  def maybe_put_created_psudoheader(conn) do
    case HTTPSignatures.signature_for_conn(conn) do
      %{"created" => created} ->
        put_req_header(conn, "(created)", created)

      _ ->
        conn
    end
  end

  def maybe_put_expires_psudoheader(conn) do
    case HTTPSignatures.signature_for_conn(conn) do
      %{"expires" => expires} ->
        put_req_header(conn, "(expires)", expires)

      _ ->
        conn
    end
  end

  defp assign_valid_signature_on_route_aliases(conn, []), do: conn

  defp assign_valid_signature_on_route_aliases(%{assigns: %{valid_signature: true}} = conn, _),
    do: conn

  defp assign_valid_signature_on_route_aliases(conn, [path | rest]) do
    request_target = String.downcase("#{conn.method}") <> " #{path}"

    conn =
      conn
      |> put_req_header("(request-target)", request_target)
      |> maybe_put_created_psudoheader()
      |> maybe_put_expires_psudoheader()

    conn
    |> assign(:valid_signature, HTTPSignatures.validate_conn(conn))
    |> assign(:signature_actor_id, signature_host(conn))
    |> assign_valid_signature_on_route_aliases(rest)
  end

  defp maybe_assign_valid_signature(conn) do
    if has_signature_header?(conn) do
      # set (request-target) header to the appropriate value
      # we also replace the digest header with the one we computed
      possible_paths =
        [conn.request_path, conn.request_path <> "?#{conn.query_string}" | route_aliases(conn)]

      conn =
        case conn do
          %{assigns: %{digest: digest}} = conn -> put_req_header(conn, "digest", digest)
          conn -> conn
        end

      assign_valid_signature_on_route_aliases(conn, possible_paths)
    else
      Logger.debug("No signature header!")
      conn
    end
  end

  defp has_signature_header?(conn) do
    conn |> get_req_header("signature") |> Enum.at(0, false)
  end

  defp maybe_require_signature(
         %{assigns: %{valid_signature: true, signature_actor_id: actor_id}} = conn
       ) do
    # inboxes implicitly need http signatures for authentication
    # so we don't really know if the instance will have broken federation after
    # we turn on authorized_fetch_mode.
    #
    # to "check" this is a signed fetch, verify if method is GET
    if conn.method == "GET" do
      actor_host = URI.parse(actor_id).host

      case @cachex.get(:request_signatures_cache, actor_host) do
        {:ok, nil} ->
          Logger.debug("Successful signature from #{actor_host}")
          Instances.set_request_signatures(actor_host)
          @cachex.put(:request_signatures_cache, actor_host, true)

        {:ok, true} ->
          :noop

        any ->
          Logger.warning(
            "expected request signature cache to return a boolean, instead got #{inspect(any)}"
          )
      end
    end

    conn
  end

  defp maybe_require_signature(conn), do: conn

  defp signature_host(conn) do
    with {:key_id, %{"keyId" => kid}} <- {:key_id, HTTPSignatures.signature_for_conn(conn)},
         {:actor_id, actor_id, _} when actor_id != nil <-
           {:actor_id, SigningKey.key_id_to_ap_id(kid), kid} do
      actor_id
    else
      {:key_id, e} ->
        Logger.error("Failed to extract key_id from signature: #{inspect(e)}")
        nil

      {:actor_id, _, kid} ->
        # SigningKeys SHOULD have been fetched before this gets called!
        Logger.error("Failed to extract actor_id from signature: signing key #{kid} not known")
        nil
    end
  end
end
