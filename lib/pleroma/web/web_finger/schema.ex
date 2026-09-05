# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger.Schema do
  @moduledoc """
  Generates WebFinger-related response data for local resources.
  """
  alias Pleroma.User
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Federator.Publisher
  alias Pleroma.XmlBuilder
  require Jason
  require Logger

  def host_meta do
    base_url = Endpoint.url()

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      {
        :Link,
        %{
          rel: "lrdd",
          type: "application/xrd+xml",
          template: "#{base_url}/.well-known/webfinger?resource={uri}"
        }
      }
    }
    |> XmlBuilder.to_doc()
  end

  def webfinger(resource, fmt) when fmt in ["XML", "JSON"] do
    host = Pleroma.Web.Endpoint.host()

    regex =
      if webfinger_domain = Pleroma.Config.get([Pleroma.Web.WebFinger, :domain]) do
        ~r/(acct:)?(?<username>[a-z0-9A-Z_\.-]+)@(#{host}|#{webfinger_domain})/
      else
        ~r/(acct:)?(?<username>[a-z0-9A-Z_\.-]+)@#{host}/
      end

    with %{"username" => username} <- Regex.named_captures(regex, resource),
         %User{} = user <- User.get_cached_by_nickname(username) do
      {:ok, represent_user(user, fmt)}
    else
      _e ->
        with %User{} = user <- User.get_cached_by_ap_id(resource),
             true <- user.local do
          {:ok, represent_user(user, fmt)}
        else
          _e ->
            {:error, "Couldn't find user"}
        end
    end
  end

  defp gather_links(%User{} = user) do
    [
      %{
        "rel" => "http://webfinger.net/rel/profile-page",
        "type" => "text/html",
        "href" => user.ap_id
      }
    ] ++ Publisher.gather_webfinger_links(user)
  end

  defp gather_aliases(%User{} = user) do
    [user.ap_id]
  end

  defp represent_user(user, "JSON") do
    %{
      "subject" => "acct:#{user.nickname}@#{domain()}",
      "aliases" => gather_aliases(user),
      "links" => gather_links(user)
    }
  end

  defp represent_user(user, "XML") do
    aliases =
      user
      |> gather_aliases()
      |> Enum.map(&{:Alias, &1})

    links =
      gather_links(user)
      |> Enum.map(fn link -> {:Link, link} end)

    {
      :XRD,
      %{xmlns: "http://docs.oasis-open.org/ns/xri/xrd-1.0"},
      [
        {:Subject, "acct:#{user.nickname}@#{domain()}"}
      ] ++ aliases ++ links
    }
    |> XmlBuilder.to_doc()
  end

  def domain do
    Pleroma.Config.get([Pleroma.Web.WebFinger, :domain]) || Pleroma.Web.Endpoint.host()
  end
end
