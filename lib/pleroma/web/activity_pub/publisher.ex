# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Publisher do
  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.Delivery
  alias Pleroma.HTTP
  alias Pleroma.Instances
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.Relay
  alias Pleroma.Web.ActivityPub.Transmogrifier

  require Pleroma.Constants

  import Pleroma.Web.ActivityPub.Visibility

  @behaviour Pleroma.Web.Federator.Publisher

  require Logger

  @moduledoc """
  ActivityPub outgoing federation module.
  """

  @doc """
  Determine if an activity can be represented by running it through Transmogrifier.
  """
  def is_representable?(%Activity{} = activity) do
    with {:ok, _data} <- Transmogrifier.prepare_outgoing(activity.data) do
      true
    else
      _e ->
        false
    end
  end

  @doc """
  Publish a single message to a peer.  Takes a struct with the following
  parameters set:

  * `inbox`: the inbox to publish to
  * `json`: the JSON message body representing the ActivityPub message
  * `actor`: the actor which is signing the message
  * `id`: the ActivityStreams URI of the message
  """
  def publish_one(
        %{"inbox" => inbox, "json" => json, "actor" => %User{} = actor, "id" => id} = params
      ) do
    Logger.debug("Federating #{id} to #{inbox}")

    signing_key = Pleroma.User.SigningKey.load_key(actor).signing_key

    with {:ok, %{status: code}} = result when code in 200..299 <-
           HTTP.post(
             inbox,
             json,
             [{"content-type", "application/activity+json"}],
             httpsig: %{signing_key: signing_key}
           ) do
      if not Map.has_key?(params, "unreachable_since") || params["unreachable_since"] do
        Instances.set_reachable(inbox)
      end

      result
    else
      {_post_result, response} ->
        fmt_error = format_error_response(response)

        case fmt_error do
          # Instance does not support federation
          # (see AP spec section 5.2)
          {:http_error, 405, _} ->
            Instances.set_consistently_unreachable(inbox)

          _ ->
            unless params["unreachable_since"], do: Instances.set_unreachable(inbox)
        end

        {:error, fmt_error}
    end
  end

  def publish_one(%{"actor_id" => actor_id} = params) do
    actor = User.get_cached_by_id(actor_id)

    params
    |> Map.delete("actor_id")
    |> Map.put("actor", actor)
    |> publish_one()
  end

  defp format_error_response(%Tesla.Env{status: code, headers: headers}),
    do: {:http_error, code, headers}

  defp format_error_response(%Tesla.Env{} = env),
    do: {:http_error, :connect, env}

  defp format_error_response(response), do: response

  defp blocked_instances do
    Config.get([:instance, :quarantined_instances], []) ++
      Config.get([:mrf_simple, :reject], [])
  end

  defp allowed_instances do
    Config.get([:mrf_simple, :accept])
  end

  def should_federate?(url) when is_binary(url) do
    %{host: host} = URI.parse(url)

    with {nil, false} <- {nil, is_nil(host)},
         allowed <- allowed_instances(),
         false <- Enum.empty?(allowed) do
      allowed
      |> Pleroma.Web.ActivityPub.MRF.instance_list_from_tuples()
      |> Pleroma.Web.ActivityPub.MRF.subdomains_regex()
      |> Pleroma.Web.ActivityPub.MRF.subdomain_match?(host)
    else
      # oi!
      {nil, true} ->
        false

      _ ->
        quarantined_instances =
          blocked_instances()
          |> Pleroma.Web.ActivityPub.MRF.instance_list_from_tuples()
          |> Pleroma.Web.ActivityPub.MRF.subdomains_regex()

        not Pleroma.Web.ActivityPub.MRF.subdomain_match?(quarantined_instances, host)
    end
  end

  def should_federate?(_), do: false

  @spec recipients(User.t(), Activity.t()) :: list(User.t()) | []
  defp recipients(actor, activity) do
    followers =
      if actor.follower_address in activity.recipients do
        User.get_external_followers(actor)
      else
        []
      end

    fetchers =
      with %Activity{data: %{"type" => "Delete"}} <- activity,
           %Object{id: object_id} <- Object.normalize(activity, fetch: false),
           fetchers <- User.get_delivered_users_by_object_id(object_id),
           _ <- Delivery.delete_all_by_object_id(object_id) do
        fetchers
      else
        _ ->
          []
      end

    Pleroma.Web.Federator.Publisher.remote_users(activity) ++ followers ++ fetchers
  end

  defp get_cc_ap_ids(ap_id, recipients) do
    host = Map.get(URI.parse(ap_id), :host)

    recipients
    |> Enum.filter(fn %User{ap_id: ap_id} -> Map.get(URI.parse(ap_id), :host) == host end)
    |> Enum.map(& &1.ap_id)
  end

  defp try_sharedinbox(%User{shared_inbox: nil, inbox: inbox}), do: inbox
  defp try_sharedinbox(%User{shared_inbox: shared_inbox}), do: shared_inbox

  @doc """
  Publishes an activity with BCC to all relevant peers.
  """

  def publish(%User{} = actor, %{data: %{"bcc" => bcc}} = activity)
      when is_list(bcc) and bcc != [] do
    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)

    recipients = recipients(actor, activity)

    inboxes =
      recipients
      |> Enum.map(fn actor -> actor.inbox end)
      |> Enum.filter(fn inbox -> should_federate?(inbox) end)
      |> Instances.filter_reachable()

    Repo.checkout(fn ->
      Enum.each(inboxes, fn {inbox, unreachable_since} ->
        %User{ap_id: ap_id} = Enum.find(recipients, fn actor -> actor.inbox == inbox end)

        # Get all the recipients on the same host and add them to cc. Otherwise, a remote
        # instance would only accept a first message for the first recipient and ignore the rest.
        cc = get_cc_ap_ids(ap_id, recipients)

        json =
          data
          |> Map.put("cc", cc)
          |> Jason.encode!()

        Pleroma.Web.Federator.Publisher.enqueue_one(__MODULE__, %{
          "inbox" => inbox,
          "json" => json,
          "actor_id" => actor.id,
          "id" => activity.data["id"],
          "unreachable_since" => unreachable_since
        })
      end)
    end)
  end

  # Publishes an activity to all relevant peers.
  def publish(%User{} = actor, %Activity{} = activity) do
    public = is_public?(activity)

    if public && Config.get([:instance, :allow_relay]) do
      Logger.debug(fn -> "Relaying #{activity.data["id"]} out" end)
      Relay.publish(activity)
    end

    {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
    json = Jason.encode!(data)

    recipients(actor, activity)
    |> Enum.map(fn %User{} = user ->
      try_sharedinbox(user)
    end)
    |> Enum.uniq()
    |> Enum.filter(fn inbox -> should_federate?(inbox) end)
    |> Instances.filter_reachable()
    |> Enum.each(fn {inbox, unreachable_since} ->
      Pleroma.Web.Federator.Publisher.enqueue_one(
        __MODULE__,
        %{
          "inbox" => inbox,
          "json" => json,
          "actor_id" => actor.id,
          "id" => activity.data["id"],
          "unreachable_since" => unreachable_since
        }
      )
    end)
  end

  def gather_webfinger_links(%User{} = user) do
    [
      %{"rel" => "self", "type" => "application/activity+json", "href" => user.ap_id},
      %{
        "rel" => "self",
        "type" => "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\"",
        "href" => user.ap_id
      },
      %{
        "rel" => "http://ostatus.org/schema/1.0/subscribe",
        "template" => "#{Pleroma.Web.Endpoint.url()}/ostatus_subscribe?acct={uri}"
      }
    ]
  end

  def gather_nodeinfo_protocol_names, do: ["activitypub"]
end
