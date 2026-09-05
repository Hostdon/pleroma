# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectView do
  use Pleroma.Web, :view
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.CollectionViewHelper
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.ActivityPub

  def render("object.json", %{object: %Object{} = object}) do
    base = Pleroma.Web.ActivityPub.Utils.make_json_ld_header()

    additional = Transmogrifier.prepare_object(object.data)
    Map.merge(base, additional)
  end

  def render("object.json", %{object: %Activity{} = activity}) do
    {:ok, ap_data} = Transmogrifier.prepare_outgoing(activity.data)
    ap_data
  end

  def render("object_replies.json", %{
        conn: conn,
        render_params: %{object_ap_id: object_ap_id, page: "true"} = params
      }) do
    params = Map.put_new(params, :limit, 40)

    items = ActivityPub.fetch_objects_for_replies_collection(object_ap_id, params)
    display_items = map_reply_collection_items(items)

    pagination = ControllerHelper.get_pagination_fields(conn, items, %{}, :asc)

    CollectionViewHelper.collection_page_keyset(display_items, pagination, params[:limit])
  end

  def render(
        "object_replies.json",
        %{
          render_params: %{object_ap_id: object_ap_id} = params
        } = opts
      ) do
    params =
      params
      |> Map.drop([:max_id, :min_id, :since_id, :object_ap_id])
      |> Map.put_new(:limit, 40)
      |> Map.put(:total, true)

    %{total: total, items: items} =
      ActivityPub.fetch_objects_for_replies_collection(object_ap_id, params)

    display_items = map_reply_collection_items(items)

    first_pagination = reply_collection_first_pagination(items, opts)

    first_page =
      if total > 0 do
        CollectionViewHelper.collection_page_keyset(
          display_items,
          first_pagination,
          params[:limit],
          true
        )
      else
        false
      end

    col_ap =
      CollectionViewHelper.collection_root_ordered(
        object_ap_id <> "/replies",
        total,
        first_page
      )

    if params[:skip_ap_ctx] do
      col_ap
    else
      Map.merge(col_ap, Pleroma.Web.ActivityPub.Utils.make_json_ld_header())
    end
  end

  defp map_reply_collection_items(items), do: Enum.map(items, fn %{ap_id: ap_id} -> ap_id end)

  defp reply_collection_first_pagination(items, %{conn: %Plug.Conn{} = conn}) do
    ControllerHelper.get_pagination_fields(conn, items, %{"page" => true}, :asc)
  end

  defp reply_collection_first_pagination(items, %{render_params: %{object_ap_id: object_ap_id}}) do
    %{
      "id" => object_ap_id <> "/replies?page=true",
      "partOf" => object_ap_id <> "/replies"
    }
    |> then(fn m ->
      case items do
        [] ->
          m

        i ->
          next_id = object_ap_id <> "/replies?page=true&min_id=#{List.last(i)[:id]}"
          Map.put(m, "next", next_id)
      end
    end)
  end
end
