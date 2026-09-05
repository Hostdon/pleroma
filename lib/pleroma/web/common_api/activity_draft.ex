# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraft do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.Visibility
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils

  use Gettext,
    backend: Pleroma.Web.Gettext

  defstruct valid?: true,
            errors: [],
            user: nil,
            params: %{},
            status: nil,
            summary: nil,
            full_payload: nil,
            attachments: [],
            in_reply_to: nil,
            language: nil,
            content_map: %{},
            quote: nil,
            visibility: nil,
            expires_at: nil,
            extra: nil,
            emoji: %{},
            content_html: nil,
            mentions: [],
            tags: [],
            to: [],
            cc: [],
            context: nil,
            sensitive: false,
            object: nil,
            preview?: false,
            changes: %{}

  defp new(user, params) do
    %__MODULE__{user: user}
    |> put_params(params)
  end

  def create(user, params) do
    new(user, params)
    |> status()
    |> summary()
    |> with_valid(&attachments/1)
    |> full_payload()
    |> expires_at()
    |> poll()
    |> with_valid(&in_reply_to/1)
    |> with_valid(&visibility/1)
    |> with_valid(&quote_id/1)
    |> content()
    |> with_valid(&language/1)
    |> with_valid(&to_and_cc/1)
    |> with_valid(&context/1)
    |> sensitive()
    |> with_valid(&object/1)
    |> preview?()
    |> with_valid(&changes/1)
    |> validate()
  end

  defp put_params(draft, params) do
    params =
      params
      |> Map.put_new(:in_reply_to_status_id, params[:in_reply_to_id])
      |> Map.put_new(:quoted_status_id, params[:quote_id])

    %{draft | params: params}
  end

  defp status(%{params: %{status: status}} = draft) do
    %{draft | status: String.trim(status)}
  end

  defp summary(%{params: params} = draft) do
    %{draft | summary: Map.get(params, :spoiler_text, "")}
  end

  defp full_payload(%{status: status, summary: summary} = draft) do
    full_payload = String.trim(status <> summary)

    case Utils.validate_character_limit(full_payload, draft.attachments) do
      :ok -> %{draft | full_payload: full_payload}
      {:error, message} -> add_error(draft, message)
    end
  end

  defp attachments(%{params: params, user: user} = draft) do
    case Utils.attachments_from_ids(user, params) do
      attachments when is_list(attachments) ->
        %{draft | attachments: attachments}

      {:error, reason} ->
        add_error(draft, reason)
    end
  end

  defp in_reply_to(%{params: %{in_reply_to_status_id: ""}} = draft), do: draft

  defp in_reply_to(%{params: %{in_reply_to_status_id: id}} = draft) when is_binary(id) do
    # If a post was deleted all its activities (except the newly added Delete) are purged too,
    # thus lookup by Create db ID will yield nil just as if it never existed in the first place.
    # We allow replying to Announce here, due to an akkomafe quirk where if presented with a Announce id
    # it will render it as if it was just the normal referenced post, but use the announce ID for all interaction.
    # (XXX: fix this in akkoma-fe, then drop such workarounds here and in all other affected places)
    with %Activity{} = activity <- Activity.get_by_id(id),
         true <- Visibility.visible_for_user?(activity, draft.user),
         {_, type} when type in ["Create", "Announce"] <- {:type, activity.data["type"]} do
      %{draft | in_reply_to: activity}
    else
      nil ->
        add_error(draft, dgettext("errors", "Parent post does not exist or was deleted"))

      false ->
        add_error(draft, dgettext("errors", "Must be able to access post to interact with it"))

      {:type, type} ->
        add_error(
          draft,
          dgettext("errors", "Can only reply to posts, not %{type} activities",
            type: inspect(type)
          )
        )
    end
  end

  defp in_reply_to(%{params: %{in_reply_to_status_id: %Activity{} = in_reply_to}} = draft) do
    %{draft | in_reply_to: in_reply_to}
  end

  defp in_reply_to(draft), do: draft

  defp can_quote(
         %User{ap_id: actor},
         %Activity{actor: quoted_author, data: %{"type" => "Create"}} = quoting,
         quote_visibility
       ) do
    quoting_visibility = CommonAPI.get_quoted_visibility(quoting)

    quoting_visibility in ["public", "unlisted"] or
      (quoting_visibility == "local" && quote_visibility == quoting_visibility) or
      (quoting_visibility == "private" && quote_visibility == quoting_visibility &&
         actor == quoted_author)
  end

  defp can_quote(_, _, _), do: false

  defp quote_id(%{params: %{quoted_status_id: ""}} = draft), do: draft

  defp quote_id(
         %{user: actor, visibility: quote_visibiliity, params: %{quoted_status_id: id}} = draft
       )
       when is_binary(id) do
    with {:activity, %Activity{} = quote} <- {:activity, Activity.get_by_id(id)},
         {:visibility, true} <- {:visibility, can_quote(actor, quote, quote_visibiliity)} do
      %{draft | quote: Activity.get_by_id(id)}
    else
      {:activity, _} ->
        add_error(draft, dgettext("errors", "You can't quote a status that doesn't exist"))

      {:visibility, false} ->
        add_error(
          draft,
          dgettext(
            "errors",
            "You cannot quote this status at all or not with the intended visibility"
          )
        )
    end
  end

  defp quote_id(%{params: %{quoted_status_id: %Activity{} = quote}} = draft) do
    %{draft | quote: quote}
  end

  defp quote_id(draft), do: draft

  defp language(%{params: %{language: language}, content_html: content} = draft)
       when is_binary(language) do
    if Pleroma.ISO639.valid_alpha2?(language) do
      %{draft | content_map: %{language => content}}
    else
      add_error(draft, dgettext("errors", "Invalid language"))
    end
  end

  defp language(%{content_html: content} = draft) do
    # Use a default language if no language is specified
    %{draft | content_map: %{"en" => content}}
  end

  defp visibility(%{params: params} = draft) do
    case CommonAPI.get_visibility(params, draft.in_reply_to) do
      {visibility, "direct"} when visibility != "direct" ->
        add_error(draft, dgettext("errors", "The message visibility must be direct"))

      {visibility, _} ->
        %{draft | visibility: visibility}
    end
  end

  defp expires_at(draft) do
    case CommonAPI.check_expiry_date(draft.params[:expires_in]) do
      {:ok, expires_at} -> %{draft | expires_at: expires_at}
      {:error, message} -> add_error(draft, message)
    end
  end

  defp poll(draft) do
    case Utils.make_poll_data(draft.params) do
      {:ok, {poll, poll_emoji}} ->
        %{draft | extra: poll, emoji: Map.merge(draft.emoji, poll_emoji)}

      {:error, message} ->
        add_error(draft, message)
    end
  end

  defp content(draft) do
    {content_html, mentioned_users, tags} = Utils.make_content_html(draft)

    mentions =
      mentioned_users
      |> Enum.map(fn {_, mentioned_user} -> mentioned_user.ap_id end)
      |> Utils.get_addressed_users(draft.params[:to])

    %{draft | content_html: content_html, mentions: mentions, tags: tags}
  end

  defp to_and_cc(draft) do
    {to, cc} = Utils.get_to_and_cc(draft)
    %{draft | to: to, cc: cc}
  end

  defp context(draft) do
    context = Utils.make_context(draft)
    %{draft | context: context}
  end

  defp sensitive(draft) do
    sensitive = draft.params[:sensitive]
    %{draft | sensitive: sensitive}
  end

  defp object(draft) do
    emoji = Map.merge(Pleroma.Emoji.Formatter.get_emoji_map(draft.full_payload), draft.emoji)

    # Sometimes people create posts with subject containing emoji,
    # since subjects are usually copied this will result in a broken
    # subject when someone replies from an instance that does not have
    # the emoji or has it under different shortcode. This is an attempt
    # to mitigate this by copying emoji from inReplyTo if they are present
    # in the subject.
    summary_emoji =
      with %Activity{} <- draft.in_reply_to,
           %Object{data: %{"tag" => [_ | _] = tag}} <- Object.normalize(draft.in_reply_to) do
        Enum.reduce(tag, %{}, fn
          %{"type" => "Emoji", "name" => name, "icon" => %{"url" => url}}, acc ->
            if String.contains?(draft.summary, name) do
              Map.put(acc, name, url)
            else
              acc
            end

          _, acc ->
            acc
        end)
      else
        _ -> %{}
      end

    emoji = Map.merge(emoji, summary_emoji)
    media_type = Utils.get_content_type(draft.params[:content_type])
    {:ok, note_data, _meta} = Builder.note(draft)

    object =
      note_data
      |> Map.put("emoji", emoji)
      |> Map.put("source", %{
        "content" => draft.status,
        "mediaType" => media_type
      })
      |> maybe_put("htmlMfm", true, media_type == "text/x.misskeymarkdown")
      |> Map.put("generator", draft.params[:generator])
      |> Map.put("contentMap", draft.content_map)

    %{draft | object: object}
  end

  defp maybe_put(map, key, value, true), do: map |> Map.put(key, value)
  defp maybe_put(map, _, _, _), do: map

  defp preview?(draft) do
    preview? = Pleroma.Web.Utils.Params.truthy_param?(draft.params[:preview])
    %{draft | preview?: preview?}
  end

  defp changes(draft) do
    direct? = draft.visibility == "direct"
    additional = %{"cc" => draft.cc, "directMessage" => direct?}

    additional =
      case draft.expires_at do
        %DateTime{} = expires_at -> Map.put(additional, "expires_at", expires_at)
        _ -> additional
      end

    changes =
      %{
        to: draft.to,
        actor: draft.user,
        context: draft.context,
        object: draft.object,
        additional: additional
      }

    %{draft | changes: changes}
  end

  defp with_valid(%{valid?: true} = draft, func), do: func.(draft)
  defp with_valid(draft, _func), do: draft

  defp add_error(draft, message) do
    %{draft | valid?: false, errors: [message | draft.errors]}
  end

  defp validate(%{valid?: true} = draft), do: {:ok, draft}
  defp validate(%{errors: [message | _]}), do: {:error, message}
end
