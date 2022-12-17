# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator do
  use Ecto.Schema

  alias Pleroma.Emoji
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false
  @emoji_regex ~r/:[A-Za-z0-9_-]+(@.+)?:/

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
        tag_fields()
      end
    end

    field(:context, :string)
    field(:content, :string)
  end

  def cast_and_validate(data) do
    data
    |> cast_data()
    |> validate_data()
  end

  def cast_data(data) do
    data =
      data
      |> fix()

    %__MODULE__{}
    |> changeset(data)
  end

  def changeset(struct, data) do
    struct
    |> cast(data, __schema__(:fields) -- [:tag])
    |> cast_embed(:tag)
  end

  defp fix(data) do
    data =
      data
      |> fix_emoji_qualification()
      |> CommonFixes.fix_actor()
      |> CommonFixes.fix_activity_addressing()

    data =
      if Map.has_key?(data, "tag") do
        data
      else
        Map.put(data, "tag", [])
      end

    case Object.normalize(data["object"]) do
      %Object{} = object ->
        data
        |> CommonFixes.fix_activity_context(object)
        |> CommonFixes.fix_object_action_recipients(object)

      _ ->
        data
    end
  end

  defp matches_shortcode?(nil), do: false
  defp matches_shortcode?(s), do: Regex.match?(@emoji_regex, s)

  defp fix_emoji_qualification(%{"content" => emoji} = data) do
    new_emoji = Pleroma.Emoji.fully_qualify_emoji(emoji)

    cond do
      Pleroma.Emoji.is_unicode_emoji?(emoji) ->
        data

      Pleroma.Emoji.is_unicode_emoji?(new_emoji) ->
        data |> Map.put("content", new_emoji)

      true ->
        data
    end
  end

  defp fix_emoji_qualification(data), do: data

  defp validate_emoji(cng) do
    content = get_field(cng, :content)

    if Emoji.is_unicode_emoji?(content) || matches_shortcode?(content) do
      cng
    else
      cng
      |> add_error(:content, "is not a valid emoji")
    end
  end

  defp maybe_validate_tag_presence(cng) do
    content = get_field(cng, :content)

    if Emoji.is_unicode_emoji?(content) do
      cng
    else
      tag = get_field(cng, :tag)
      emoji_name = Emoji.stripped_name(content)

      case tag do
        [%{name: ^emoji_name, type: "Emoji", icon: %{url: _}}] ->
          cng

        _ ->
          cng
          |> add_error(:tag, "does not contain an Emoji tag")
      end
    end
  end

  defp validate_data(data_cng) do
    data_cng
    |> validate_inclusion(:type, ["EmojiReact"])
    |> validate_required([:id, :type, :object, :actor, :context, :to, :cc, :content])
    |> validate_actor_presence()
    |> validate_object_presence()
    |> validate_emoji()
    |> maybe_validate_tag_presence()
  end
end
