# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ArticleNotePageValidator do
  use Ecto.Schema
  alias Pleroma.User
  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object.Fetcher
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset

  require Logger

  @primary_key false
  @derive Jason.Encoder

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        object_fields()
        status_object_fields()
      end
    end

    field(:replies, {:array, ObjectValidators.ObjectID}, default: [])
    field(:source, :map)
  end

  def cast_and_apply(data) do
    data
    |> cast_data
    |> apply_action(:insert)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    %__MODULE__{}
    |> changeset(data)
  end

  defp fix_url(%{"url" => url} = data) when is_bitstring(url), do: data
  defp fix_url(%{"url" => url} = data) when is_map(url), do: Map.put(data, "url", url["href"])
  defp fix_url(data), do: data

  defp fix_tag(%{"tag" => tag} = data) when is_list(tag), do: data
  defp fix_tag(%{"tag" => tag} = data) when is_map(tag), do: Map.put(data, "tag", [tag])
  defp fix_tag(data), do: Map.drop(data, ["tag"])

  defp fix_replies(%{"replies" => %{"first" => %{"items" => replies}}} = data)
       when is_list(replies),
       do: Map.put(data, "replies", replies)

  defp fix_replies(%{"replies" => %{"items" => replies}} = data) when is_list(replies),
    do: Map.put(data, "replies", replies)

  defp fix_replies(%{"replies" => replies} = data) when is_bitstring(replies),
    do: Map.drop(data, ["replies"])

  defp fix_replies(%{"replies" => %{"first" => first}} = data) do
    with {:ok, %{"orderedItems" => replies}} <-
           Fetcher.fetch_and_contain_remote_object_from_id(first) do
      Map.put(data, "replies", replies)
    else
      {:error, _} ->
        Logger.error("Could not fetch replies for #{first}")
        Map.put(data, "replies", [])
    end
  end

  defp fix_replies(data), do: data

  defp remote_mention_resolver(
         %{"id" => ap_id, "tag" => tags},
         "@" <> nickname = mention,
         buffer,
         opts,
         acc
       ) do
    initial_host =
      ap_id
      |> URI.parse()
      |> Map.get(:host)

    with mention_tag <-
           Enum.find(tags, fn t ->
             t["type"] == "Mention" &&
               (t["name"] == mention || mention == "#{t["name"]}@#{initial_host}")
           end),
         false <- is_nil(mention_tag),
         {:ok, %User{} = user} <- User.get_or_fetch_by_ap_id(mention_tag["href"]) do
      link = Pleroma.Formatter.mention_tag(user, nickname, opts)
      {link, %{acc | mentions: MapSet.put(acc.mentions, {"@" <> nickname, user})}}
    else
      _ -> {buffer, acc}
    end
  end

  # https://github.com/misskey-dev/misskey/pull/8787
  defp fix_misskey_content(
         %{"source" => %{"mediaType" => "text/x.misskeymarkdown", "content" => content}} = object
       )
       when is_binary(content) do
    mention_handler = fn nick, buffer, opts, acc ->
      remote_mention_resolver(object, nick, buffer, opts, acc)
    end

    {linked, _, _} =
      Utils.format_input(content, "text/x.misskeymarkdown", mention_handler: mention_handler)

    Map.put(object, "content", linked)
  end

  defp fix_misskey_content(%{"_misskey_content" => content} = object) when is_binary(content) do
    mention_handler = fn nick, buffer, opts, acc ->
      remote_mention_resolver(object, nick, buffer, opts, acc)
    end

    {linked, _, _} =
      Utils.format_input(content, "text/x.misskeymarkdown", mention_handler: mention_handler)

    object
    |> Map.put("source", %{
      "content" => content,
      "mediaType" => "text/x.misskeymarkdown"
    })
    |> Map.put("content", linked)
    |> Map.delete("_misskey_content")
  end

  defp fix_misskey_content(data), do: data

  defp fix_source(%{"source" => source} = object) when is_binary(source) do
    object
    |> Map.put("source", %{"content" => source})
  end

  defp fix_source(object), do: object

  defp fix(data) do
    data
    |> CommonFixes.fix_actor()
    |> CommonFixes.fix_object_defaults()
    |> fix_url()
    |> fix_tag()
    |> fix_replies()
    |> fix_source()
    |> fix_misskey_content()
    |> Transmogrifier.fix_attachments()
    |> Transmogrifier.fix_emoji()
    |> Transmogrifier.fix_content_map()
  end

  def changeset(struct, data) do
    data = fix(data)

    struct
    |> cast(data, __schema__(:fields) -- [:attachment, :tag])
    |> cast_embed(:attachment)
    |> cast_embed(:tag)
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["Article", "Note", "Page"])
    |> validate_required([:id, :actor, :attributedTo, :type, :context, :context_id])
    |> CommonValidations.validate_any_presence([:cc, :to])
    |> CommonValidations.validate_fields_match([:actor, :attributedTo])
    |> CommonValidations.validate_actor_presence()
    |> CommonValidations.validate_host_match()
  end
end
