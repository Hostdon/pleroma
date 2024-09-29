# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy do
  require Logger

  alias Pleroma.Config
  alias Pleroma.Emoji.Pack

  @moduledoc "Detect new emojis by their shortcode and steals them"
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  @pack_name "stolen"

  # Config defaults
  @size_limit 50_000
  @download_unknown_size false

  defp create_pack() do
    with {:ok, pack} = Pack.create(@pack_name) do
      Pack.save_metadata(
        %{
          "description" => "Collection of emoji auto-stolen from other instances",
          "homepage" => Pleroma.Web.Endpoint.url(),
          "can-download" => false,
          "share-files" => false
        },
        pack
      )
    end
  end

  defp load_or_create_pack() do
    case Pack.load_pack(@pack_name) do
      {:ok, pack} -> {:ok, pack}
      {:error, :enoent} -> create_pack()
      e -> e
    end
  end

  defp add_emoji(shortcode, extension, filedata) do
    {:ok, pack} = load_or_create_pack()
    # Make final path infeasible to predict to thwart certain kinds of attacks
    # (48 bits is slighty more than 8 base62 chars, thus 9 chars)
    salt =
      :crypto.strong_rand_bytes(6)
      |> :crypto.bytes_to_integer()
      |> Base62.encode()
      |> String.pad_leading(9, "0")

    filename = shortcode <> "-" <> salt <> "." <> extension

    Pack.add_file(pack, shortcode, filename, filedata)
  end

  defp accept_host?(host), do: host in Config.get([:mrf_steal_emoji, :hosts], [])

  defp shortcode_matches?(shortcode, pattern) when is_binary(pattern) do
    shortcode == pattern
  end

  defp shortcode_matches?(shortcode, pattern) do
    String.match?(shortcode, pattern)
  end

  defp reject_emoji?({shortcode, _url}, installed_emoji) do
    valid_shortcode? = String.match?(shortcode, ~r/^[a-zA-Z0-9_-]+$/)

    rejected_shortcode? =
      [:mrf_steal_emoji, :rejected_shortcodes]
      |> Config.get([])
      |> Enum.any?(fn pattern -> shortcode_matches?(shortcode, pattern) end)

    emoji_installed? = Enum.member?(installed_emoji, shortcode)

    !valid_shortcode? or rejected_shortcode? or emoji_installed?
  end

  defp steal_emoji(%{} = response, {shortcode, extension}) do
    case add_emoji(shortcode, extension, response.body) do
      {:ok, _} ->
        shortcode

      e ->
        Logger.warning(
          "MRF.StealEmojiPolicy: Failed to add #{shortcode} as #{extension}: #{inspect(e)}"
        )

        nil
    end
  end

  defp get_extension_if_safe(response) do
    content_type =
      :proplists.get_value("content-type", response.headers, MIME.from_path(response.url))

    case content_type do
      "image/" <> _ -> List.first(MIME.extensions(content_type))
      _ -> nil
    end
  end

  defp is_remote_size_within_limit?(url) do
    with {:ok, %{status: status, headers: headers} = _response} when status in 200..299 <-
           Pleroma.HTTP.request(:head, url, nil, [], []) do
      content_length = :proplists.get_value("content-length", headers, nil)
      size_limit = Config.get([:mrf_steal_emoji, :size_limit], @size_limit)

      accept_unknown =
        Config.get([:mrf_steal_emoji, :download_unknown_size], @download_unknown_size)

      content_length <= size_limit or
        (content_length == nil and accept_unknown)
    else
      _ -> false
    end
  end

  defp maybe_steal_emoji({shortcode, url}) do
    url = Pleroma.Web.MediaProxy.url(url)

    with {:remote_size, true} <- {:remote_size, is_remote_size_within_limit?(url)},
         {:ok, %{status: status} = response} when status in 200..299 <- Pleroma.HTTP.get(url) do
      size_limit = Config.get([:mrf_steal_emoji, :size_limit], @size_limit)
      extension = get_extension_if_safe(response)

      if byte_size(response.body) <= size_limit and extension do
        steal_emoji(response, {shortcode, extension})
      else
        Logger.debug(
          "MRF.StealEmojiPolicy: :#{shortcode}: at #{url} (#{byte_size(response.body)} B) over size limit (#{size_limit} B)"
        )

        nil
      end
    else
      e ->
        Logger.warning("MRF.StealEmojiPolicy: Failed to fetch #{url}: #{inspect(e)}")
        nil
    end
  end

  @impl true
  def filter(%{"object" => %{"emoji" => foreign_emojis, "actor" => actor}} = message) do
    host = URI.parse(actor).host

    if host != Pleroma.Web.Endpoint.host() and accept_host?(host) do
      installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)

      new_emojis =
        foreign_emojis
        |> Enum.reject(&reject_emoji?(&1, installed_emoji))
        |> Enum.map(&maybe_steal_emoji(&1))
        |> Enum.filter(& &1)

      if !Enum.empty?(new_emojis) do
        Logger.info("Stole new emojis: #{inspect(new_emojis)}")
        Pleroma.Emoji.reload()
      end
    end

    {:ok, message}
  end

  def filter(message), do: {:ok, message}

  @impl true
  @spec config_description :: %{
          children: [
            %{
              description: <<_::272, _::_*256>>,
              key: :hosts | :rejected_shortcodes | :size_limit,
              suggestions: [any(), ...],
              type: {:list, :string} | {:list, :string} | :integer
            },
            ...
          ],
          description: <<_::448>>,
          key: :mrf_steal_emoji,
          label: <<_::80>>,
          related_policy: <<_::352>>
        }
  def config_description do
    %{
      key: :mrf_steal_emoji,
      related_policy: "Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy",
      label: "MRF Emojis",
      description: "Steals emojis from selected instances when it sees them.",
      children: [
        %{
          key: :hosts,
          type: {:list, :string},
          description: "List of hosts to steal emojis from",
          suggestions: [""]
        },
        %{
          key: :rejected_shortcodes,
          type: {:list, :string},
          description: """
            A list of patterns or matches to reject shortcodes with.

            Each pattern can be a string or [Regex](https://hexdocs.pm/elixir/Regex.html) in the format of `~r/PATTERN/`.
          """,
          suggestions: ["foo", ~r/foo/]
        },
        %{
          key: :size_limit,
          type: :integer,
          description: "File size limit (in bytes), checked before an emoji is saved to the disk",
          suggestions: ["100000"]
        }
      ]
    }
  end

  @impl true
  def describe do
    {:ok, %{}}
  end
end
