# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  @mastodon_api_level "2.7.2"

  def render("show.json", opts) do
    instance = Config.get(:instance)
    for_user = opts[:for]

    %{
      uri: Pleroma.Web.WebFinger.Schema.domain(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      short_description:
        Keyword.get(instance, :short_description) || Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Pleroma.Stats.get_stats(),
      thumbnail:
        URI.merge(Pleroma.Web.Endpoint.url(), Keyword.get(instance, :instance_thumbnail))
        |> to_string,
      languages: Keyword.get(instance, :languages, ["en"]),
      registrations: Keyword.get(instance, :registrations_open),
      approval_required: Keyword.get(instance, :account_approval_required),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      poll_limits: Keyword.get(instance, :poll_limits),
      upload_limit: Keyword.get(instance, :upload_limit),
      avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
      background_upload_limit: Keyword.get(instance, :background_upload_limit),
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
      background_image: Pleroma.Web.Endpoint.url() <> Keyword.get(instance, :background_image),
      description_limit: Keyword.get(instance, :description_limit),
      pleroma: %{
        metadata: %{
          account_activation_required: Keyword.get(instance, :account_activation_required),
          features: features(),
          federation: federation(for_user),
          fields_limits: fields_limits(),
          post_formats: Config.get([:instance, :allowed_post_formats]),
          privileged_staff: Config.get([:instance, :privileged_staff])
        },
        stats: %{mau: Pleroma.User.active_user_count()},
        vapid_public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    }
  end

  def render("translation_languages.json", %{
        source_languages: source_languages,
        destination_languages: destination_languages
      }) do
    source_language_codes = Enum.map(source_languages, fn lang -> lang.code end)
    dest_language_codes = Enum.map(destination_languages, fn lang -> lang.code end)

    Map.new(source_language_codes, fn language ->
      {language, dest_language_codes -- [language]}
    end)
  end

  def features do
    [
      "pleroma_api",
      "akkoma_api",
      "mastodon_api",
      "mastodon_api_streaming",
      "polls",
      "v2_suggestions",
      "pleroma_explicit_addressing",
      "shareable_emoji_packs",
      "multifetch",
      "pleroma:api/v1/notifications:include_types_filter",
      "quote_posting",
      "editing",
      if !Enum.empty?(Config.get([:instance, :local_bubble], [])) do
        "bubble_timeline"
      end,
      if Config.get([:media_proxy, :enabled]) do
        "media_proxy"
      end,
      if Config.get([:instance, :allow_relay]) do
        "relay"
      end,
      if Config.get([:instance, :safe_dm_mentions]) do
        "safe_dm_mentions"
      end,
      "pleroma_emoji_reactions",
      if Config.get([:instance, :show_reactions]) do
        "exposable_reactions"
      end,
      if Config.get([:instance, :profile_directory]) do
        "profile_directory"
      end,
      if Config.get([:translator, :enabled], false) do
        "akkoma:machine_translation"
      end,
      "custom_emoji_reactions",
      "pleroma:get:main/ostatus"
    ]
    |> Enum.filter(& &1)
  end

  def federation(for_user \\ nil) do
    mrf_transparency = Config.get([:mrf, :transparency])

    cond do
      mrf_transparency == true ->
        mrf_info()

      mrf_transparency == :authenticated && for_user && for_user.local ->
        mrf_info()

      true ->
        %{}
    end
    |> Map.put(:enabled, Config.get([:instance, :federating]))
  end

  defp mrf_info() do
    quarantined = Config.get([:instance, :quarantined_instances], [])
    {:ok, data} = MRF.describe()

    data
    |> Map.put(
      :quarantined_instances,
      Enum.map(quarantined, fn {instance, _reason} -> instance end)
    )
    # This is for backwards compatibility. We originally didn't sent
    # extra info like a reason why an instance was rejected/quarantined/etc.
    # Because we didn't want to break backwards compatibility it was decided
    # to add an extra "info" key.
    |> Map.put(:quarantined_instances_info, %{
      "quarantined_instances" =>
        quarantined
        |> Enum.map(fn {instance, reason} -> {instance, %{"reason" => reason}} end)
        |> Map.new()
    })
  end

  def fields_limits do
    %{
      max_fields: Config.get([:instance, :max_account_fields]),
      max_remote_fields: Config.get([:instance, :max_remote_account_fields]),
      name_length: Config.get([:instance, :account_field_name_length]),
      value_length: Config.get([:instance, :account_field_value_length])
    }
  end
end
