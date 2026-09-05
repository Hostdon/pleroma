# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.EmojiReactValidator do
  use Ecto.Schema

  alias Pleroma.Emoji
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ObjectValidators.CommonFixes
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

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
      |> Transmogrifier.fix_tag()
      |> fix_emoji_qualification()
      |> CommonFixes.fix_actor()
      |> CommonFixes.fix_activity_addressing()
      |> prune_tags()
      |> drop_remote_indicator()

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

    if Emoji.is_unicode_emoji?(content) || Emoji.matches_shortcode?(content) do
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
    |> validate_object_presence(allowed_object_categories: [:object])
    |> validate_emoji()
    |> maybe_validate_tag_presence()
  end

  # All tags but the single emoji tag corresponding to the used custom emoji (if any)
  # are ignored anyway. Having a known single-element array makes further processing easier.
  # Also ensures the Emoji tag uses a pre-stripped name
  defp prune_tags(%{"content" => emoji, "tag" => tags} = data) do
    clean_emoji = Emoji.stripped_name(emoji)

    pruned_tags =
      Enum.reduce_while(tags, [], fn
        %{"type" => "Emoji", "name" => name} = tag, res ->
          clean_name = Emoji.stripped_name(name)

          if clean_name == clean_emoji do
            {:halt, [%{tag | "name" => clean_name}]}
          else
            {:cont, res}
          end

        _, res ->
          {:cont, res}
      end)

    %{data | "tag" => pruned_tags}
  end

  defp prune_tags(data), do: data

  # some software, like Iceshrimp.NET, federates emoji reaction with (from its POV) remote emoji
  # with the source instance added to the name in AP as an @ postfix, similar to how it’s handled
  # in Akkoma’s REST API.
  # However, this leads to duplicated remote indicators being presented to our clients an can cause
  # issues when trying to split the values we receive from REST API. Thus just drop them here.
  defp drop_remote_indicator(%{"content" => emoji, "tag" => tag} = data) when is_list(tag) do
    if String.contains?(emoji, "@") do
      stripped_emoji = Emoji.stripped_name(emoji)
      [clean_emoji | _] = String.split(stripped_emoji, "@", parts: 2)

      clean_tag =
        Enum.map(tag, fn
          %{"name" => ^stripped_emoji} = t -> %{t | "name" => clean_emoji}
          t -> t
        end)

      %{data | "content" => ":" <> clean_emoji <> ":", "tag" => clean_tag}
    else
      data
    end
  end

  defp drop_remote_indicator(data), do: data
end
