# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Relay do
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  require Logger

  @relay_nickname "relay"

  def get_actor do
    actor =
      relay_ap_id()
      |> User.get_or_create_service_actor_by_ap_id(@relay_nickname)

    actor
  end

  def relay_ap_id do
    "#{Pleroma.Web.Endpoint.url()}/relay"
  end

  @spec follow(String.t()) :: {:ok, Activity.t()} | {:error, any()}
  def follow(target_instance) do
    with %User{} = local_user <- get_actor(),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.follow(local_user, target_user) do
      Logger.info("relay: followed instance: #{target_instance}; id=#{activity.data["id"]}")
      {:ok, activity}
    else
      error -> format_error(error)
    end
  end

  @spec unfollow(String.t()) :: {:ok, Activity.t()} | {:error, any()}
  def unfollow(target_instance) do
    with %User{} = local_user <- get_actor(),
         {:ok, %User{} = target_user} <- User.get_or_fetch_by_ap_id(target_instance),
         {:ok, activity} <- ActivityPub.unfollow(local_user, target_user) do
      User.unfollow(local_user, target_user)
      Logger.info("relay: unfollowed instance: #{target_instance}: id=#{activity.data["id"]}")
      {:ok, activity}
    else
      error -> format_error(error)
    end
  end

  @spec publish(any()) :: {:ok, Activity.t(), Object.t()} | {:error, any()}
  def publish(%Activity{data: %{"type" => "Create"}} = activity) do
    with %User{} = user <- get_actor(),
         %Object{} = object <- Object.normalize(activity) do
      ActivityPub.announce(user, object, nil, true, false)
    else
      error -> format_error(error)
    end
  end

  def publish(_), do: {:error, "Not implemented"}

  @spec list(boolean()) :: {:ok, [String.t()]} | {:error, any()}
  def list(with_not_accepted \\ false) do
    with %User{} = user <- get_actor() do
      accepted =
        user
        |> User.following()
        |> Enum.map(fn entry -> URI.parse(entry).host end)
        |> Enum.uniq()

      list =
        if with_not_accepted do
          without_accept =
            user
            |> Pleroma.Activity.following_requests_for_actor()
            |> Enum.map(fn a -> URI.parse(a.data["object"]).host <> " (no Accept received)" end)
            |> Enum.uniq()

          accepted ++ without_accept
        else
          accepted
        end

      {:ok, list}
    else
      error -> format_error(error)
    end
  end

  defp format_error({:error, error}), do: format_error(error)

  defp format_error(error) do
    Logger.error("error: #{inspect(error)}")
    {:error, error}
  end
end
