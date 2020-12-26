# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatController do
  use Pleroma.Web, :controller

  import Pleroma.Web.ControllerHelper, only: [add_link_headers: 2]

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Object
  alias Pleroma.Pagination
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView
  alias Pleroma.Web.PleromaAPI.ChatView
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  import Ecto.Query

  action_fallback(Pleroma.Web.MastodonAPI.FallbackController)

  plug(
    OAuthScopesPlug,
    %{scopes: ["write:chats"]}
    when action in [
           :post_chat_message,
           :create,
           :mark_as_read,
           :mark_message_as_read,
           :delete_message
         ]
  )

  plug(
    OAuthScopesPlug,
    %{scopes: ["read:chats"]} when action in [:messages, :index, :show]
  )

  plug(OpenApiSpex.Plug.CastAndValidate, render_error: Pleroma.Web.ApiSpec.RenderError)

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.ChatOperation

  def delete_message(%{assigns: %{user: %{id: user_id} = user}} = conn, %{
        message_id: message_id,
        id: chat_id
      }) do
    with %MessageReference{} = cm_ref <-
           MessageReference.get_by_id(message_id),
         ^chat_id <- to_string(cm_ref.chat_id),
         %Chat{user_id: ^user_id} <- Chat.get_by_id(chat_id),
         {:ok, _} <- remove_or_delete(cm_ref, user) do
      conn
      |> put_view(MessageReferenceView)
      |> render("show.json", chat_message_reference: cm_ref)
    else
      _e ->
        {:error, :could_not_delete}
    end
  end

  defp remove_or_delete(
         %{object: %{data: %{"actor" => actor, "id" => id}}},
         %{ap_id: actor} = user
       ) do
    with %Activity{} = activity <- Activity.get_create_by_object_ap_id(id) do
      CommonAPI.delete(activity.id, user)
    end
  end

  defp remove_or_delete(cm_ref, _), do: MessageReference.delete(cm_ref)

  def post_chat_message(
        %{body_params: params, assigns: %{user: user}} = conn,
        %{id: id}
      ) do
    with {:ok, chat} <- Chat.get_by_user_and_id(user, id),
         %User{} = recipient <- User.get_cached_by_ap_id(chat.recipient),
         {:ok, activity} <-
           CommonAPI.post_chat_message(user, recipient, params[:content],
             media_id: params[:media_id]
           ),
         message <- Object.normalize(activity, false),
         cm_ref <- MessageReference.for_chat_and_object(chat, message) do
      conn
      |> put_view(MessageReferenceView)
      |> render("show.json", chat_message_reference: cm_ref)
    else
      {:reject, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: message})
    end
  end

  def mark_message_as_read(
        %{assigns: %{user: %{id: user_id}}} = conn,
        %{id: chat_id, message_id: message_id}
      ) do
    with %MessageReference{} = cm_ref <- MessageReference.get_by_id(message_id),
         ^chat_id <- to_string(cm_ref.chat_id),
         %Chat{user_id: ^user_id} <- Chat.get_by_id(chat_id),
         {:ok, cm_ref} <- MessageReference.mark_as_read(cm_ref) do
      conn
      |> put_view(MessageReferenceView)
      |> render("show.json", chat_message_reference: cm_ref)
    end
  end

  def mark_as_read(
        %{body_params: %{last_read_id: last_read_id}, assigns: %{user: user}} = conn,
        %{id: id}
      ) do
    with {:ok, chat} <- Chat.get_by_user_and_id(user, id),
         {_n, _} <- MessageReference.set_all_seen_for_chat(chat, last_read_id) do
      conn
      |> put_view(ChatView)
      |> render("show.json", chat: chat)
    end
  end

  def messages(%{assigns: %{user: user}} = conn, %{id: id} = params) do
    with {:ok, chat} <- Chat.get_by_user_and_id(user, id) do
      chat_message_refs =
        chat
        |> MessageReference.for_chat_query()
        |> Pagination.fetch_paginated(params)

      conn
      |> add_link_headers(chat_message_refs)
      |> put_view(MessageReferenceView)
      |> render("index.json", chat_message_references: chat_message_refs)
    end
  end

  def index(%{assigns: %{user: %{id: user_id} = user}} = conn, _params) do
    blocked_ap_ids = User.blocked_users_ap_ids(user)

    chats =
      Chat.for_user_query(user_id)
      |> where([c], c.recipient not in ^blocked_ap_ids)
      |> Repo.all()

    conn
    |> put_view(ChatView)
    |> render("index.json", chats: chats)
  end

  def create(%{assigns: %{user: user}} = conn, %{id: id}) do
    with %User{ap_id: recipient} <- User.get_cached_by_id(id),
         {:ok, %Chat{} = chat} <- Chat.get_or_create(user.id, recipient) do
      conn
      |> put_view(ChatView)
      |> render("show.json", chat: chat)
    end
  end

  def show(%{assigns: %{user: user}} = conn, %{id: id}) do
    with {:ok, chat} <- Chat.get_by_user_and_id(user, id) do
      conn
      |> put_view(ChatView)
      |> render("show.json", chat: chat)
    end
  end
end
