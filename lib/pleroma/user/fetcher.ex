# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# Copyright © 2026 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Fetcher do
  alias Akkoma.Collections
  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.Object.Fetcher, as: APFetcher
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.ObjectValidators.UserValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.WebFinger

  import Pleroma.Web.ActivityPub.Utils

  require Logger

  @spec get_actor_url(any()) :: binary() | nil
  defp get_actor_url(url) when is_binary(url), do: url
  defp get_actor_url(%{"href" => href}) when is_binary(href), do: href

  defp get_actor_url(url) when is_list(url) do
    url
    |> List.first()
    |> get_actor_url()
  end

  defp get_actor_url(_url), do: nil

  defp maybe_put_description(map, %{"summary" => description}) when is_binary(description) do
    Map.put(map, "name", description)
  end

  defp maybe_put_description(map, %{"name" => description}) when is_binary(description) do
    Map.put(map, "name", description)
  end

  defp maybe_put_description(map, _), do: map

  defp normalize_image(%{"url" => url} = data) do
    %{
      "type" => "Image",
      "url" => [%{"href" => url}]
    }
    |> maybe_put_description(data)
  end

  defp normalize_image(urls) when is_list(urls), do: urls |> List.first() |> normalize_image()
  defp normalize_image(_), do: nil

  defp normalize_also_known_as(aka) when is_list(aka), do: aka
  defp normalize_also_known_as(aka) when is_binary(aka), do: [aka]
  defp normalize_also_known_as(nil), do: []

  defp normalize_attachment(%{} = attachment), do: [attachment]
  defp normalize_attachment(attachment) when is_list(attachment), do: attachment
  defp normalize_attachment(_), do: []

  defp maybe_make_public_key_object(data) do
    if is_map(data["publicKey"]) && is_binary(data["publicKey"]["publicKeyPem"]) do
      %{
        public_key: data["publicKey"]["publicKeyPem"],
        key_id: data["publicKey"]["id"]
      }
    else
      nil
    end
  end

  defp try_fallback_nick(%{"id" => ap_id, "preferredUsername" => name})
       when is_binary(name) and is_binary(ap_id) do
    with true <- name != "",
         domain when domain != nil and domain != "" <- URI.parse(ap_id).host do
      "#{name}@#{domain}"
    else
      _ -> nil
    end
  end

  defp try_fallback_nick(_), do: nil

  defp object_to_user_data(data, verified_nick) do
    fields =
      data
      |> Map.get("attachment", [])
      |> normalize_attachment()
      |> Enum.filter(fn
        %{"type" => t} -> t == "PropertyValue"
        _ -> false
      end)
      |> Enum.map(fn fields -> Map.take(fields, ["name", "value"]) end)

    emojis =
      data
      |> Map.get("tag", [])
      |> Enum.filter(fn
        %{"type" => "Emoji"} -> true
        _ -> false
      end)
      |> Map.new(fn %{"icon" => %{"url" => url}, "name" => name} ->
        {String.trim(name, ":"), url}
      end)

    is_locked = data["manuallyApprovesFollowers"] || false
    data = Transmogrifier.maybe_fix_user_object(data)
    is_discoverable = data["discoverable"] || false
    invisible = data["invisible"] || false
    actor_type = data["type"] || "Person"

    {featured_address, pinned_objects} =
      case process_featured_collection(data["featured"]) do
        {:ok, featured_address, pinned_objects} -> {featured_address, pinned_objects}
        _ -> {nil, %{}}
      end

    # first, check that the owner is correct
    signing_key =
      if data["id"] !== data["publicKey"]["owner"] do
        Logger.error(
          "Owner of the public key is not the same as the actor - not saving the public key."
        )

        nil
      else
        maybe_make_public_key_object(data)
      end

    shared_inbox =
      if is_map(data["endpoints"]) && is_binary(data["endpoints"]["sharedInbox"]) do
        data["endpoints"]["sharedInbox"]
      end

    # can still be nil if no name was indicated in AP data
    nickname = verified_nick || try_fallback_nick(data)

    # also_known_as must be a URL
    also_known_as =
      data
      |> Map.get("alsoKnownAs", [])
      |> normalize_also_known_as()
      |> Enum.filter(fn url ->
        case URI.parse(url) do
          %URI{scheme: "http"} -> true
          %URI{scheme: "https"} -> true
          _ -> false
        end
      end)

    %{
      ap_id: data["id"],
      uri: get_actor_url(data["url"]),
      banner: normalize_image(data["image"]),
      background: normalize_image(data["backgroundUrl"]),
      fields: fields,
      emoji: emojis,
      is_locked: is_locked,
      is_discoverable: is_discoverable,
      invisible: invisible,
      avatar: normalize_image(data["icon"]),
      name: data["name"],
      follower_address: data["followers"],
      following_address: data["following"],
      featured_address: featured_address,
      bio: data["summary"] || "",
      actor_type: actor_type,
      also_known_as: also_known_as,
      signing_key: signing_key,
      inbox: data["inbox"],
      shared_inbox: shared_inbox,
      pinned_objects: pinned_objects,
      nickname: nickname
    }
  end

  defp collection_private(%{"first" => %{"type" => type}})
       when type in ["CollectionPage", "OrderedCollectionPage"],
       do: false

  defp collection_private(%{"first" => first}) do
    with {:ok, %{"type" => type}} when type in ["CollectionPage", "OrderedCollectionPage"] <-
           APFetcher.fetch_and_contain_remote_object_from_id(first) do
      false
    else
      _ -> true
    end
  end

  defp collection_private(_data), do: true

  defp counter_private(%{"totalItems" => _}), do: false
  defp counter_private(_), do: true

  defp normalize_counter(counter) when is_integer(counter), do: counter
  defp normalize_counter(_), do: 0

  defp eval_collection_counter(apid) when is_binary(apid) do
    case APFetcher.fetch_and_contain_remote_object_from_id(apid) do
      {:ok, data} ->
        {collection_private(data), counter_private(data), normalize_counter(data["totalItems"])}

      _ ->
        Logger.debug("Failed to fetch follower/ing collection #{apid}; assuming private")
        {true, true, 0}
    end
  end

  defp eval_collection_counter(_), do: {true, true, 0}

  def fetch_follow_information_for_user(user) do
    {hide_follows, hide_follows_count, following_count} =
      eval_collection_counter(user.following_address)

    {hide_followers, hide_followers_count, follower_count} =
      eval_collection_counter(user.follower_address)

    {:ok,
     %{
       hide_follows: hide_follows,
       hide_follows_count: hide_follows_count,
       following_count: following_count,
       hide_followers: hide_followers,
       hide_followers_count: hide_followers_count,
       follower_count: follower_count
     }}
  end

  def maybe_update_follow_information(user_data) do
    with {:enabled, true} <- {:enabled, Config.get([:instance, :external_user_synchronization])},
         {_, true} <-
           {:collections_available,
            !!(user_data[:following_address] && user_data[:follower_address])},
         {:ok, follow_info} <-
           fetch_follow_information_for_user(user_data) do
      Map.merge(user_data, follow_info)
    else
      {:user_type_check, false} ->
        user_data

      {:collections_available, false} ->
        user_data

      {:enabled, false} ->
        user_data

      e ->
        Logger.error(
          "Follower/Following counter update for #{user_data.ap_id} failed.\n" <> inspect(e)
        )

        user_data
    end
  end

  def maybe_handle_clashing_nickname(data) do
    with nickname when is_binary(nickname) <- data[:nickname],
         %User{} = old_user <- User.get_by_nickname(nickname),
         {_, false} <- {:ap_id_comparison, data[:ap_id] == old_user.ap_id} do
      Logger.info(
        "Found an old user for #{nickname}, the old ap id is #{old_user.ap_id}, new one is #{data[:ap_id]}, renaming.
"
      )

      old_user
      |> User.remote_user_changeset(%{nickname: "#{old_user.id}.#{old_user.nickname}"})
      |> User.update_and_set_cache()
    else
      {:ap_id_comparison, true} ->
        Logger.info(
          "Found an old user for #{data[:nickname]}, but the ap id #{data[:ap_id]} is the same as the new user. Race
condition? Not changing anything."
        )

      _ ->
        nil
    end
  end

  def process_featured_collection(nil), do: {:ok, nil, %{}}
  def process_featured_collection(""), do: {:ok, nil, %{}}

  def process_featured_collection(featured_collection) do
    featured_address =
      case get_ap_id(featured_collection) do
        id when is_binary(id) -> id
        _ -> nil
      end

    # TODO: allow passing item/page limit as function opt and use here
    case Collections.Fetcher.fetch_collection(featured_collection) do
      {:ok, items} ->
        now = NaiveDateTime.utc_now()
        dated_obj_ids = Map.new(items, fn obj -> {get_ap_id(obj), now} end)
        {:ok, featured_address, dated_obj_ids}

      error ->
        Logger.error(
          "Could not decode featured collection at fetch #{inspect(featured_collection)}: #{inspect(error)}"
        )

        error =
          case error do
            {:error, e} -> e
            e -> e
          end

        {:error, error}
    end
  end

  def enqueue_pin_fetches(%{pinned_objects: pins}) do
    # enqueue a task to fetch all pinned objects
    Enum.each(pins, fn {ap_id, _} ->
      if is_nil(Object.get_cached_by_ap_id(ap_id)) do
        Pleroma.Workers.RemoteFetcherWorker.enqueue("fetch_remote", %{
          "id" => ap_id,
          "depth" => 1
        })
      end
    end)
  end

  def enqueue_pin_fetches(_), do: nil

  def validate_and_cast(data, verified_nick) do
    with {:ok, data} <- MRF.filter(data),
         {:valid, {:ok, _, _}} <- {:valid, UserValidator.validate(data, [])} do
      {:ok, object_to_user_data(data, verified_nick)}
    else
      {:valid, reason} ->
        {:error, {:validate, reason}}

      e ->
        {:error, e}
    end
  end

  defp insert_or_update(%User{} = olduser, newdata) do
    olduser
    |> User.remote_user_changeset(newdata)
    |> User.update_and_set_cache()
  end

  defp insert_or_update(nil, newdata) do
    newdata
    |> User.remote_user_changeset()
    |> Repo.insert()
    |> User.set_cache()
  end

  defp make_user_from_apdata_and_nick(ap_data, verified_nick, olduser \\ nil) do
    with {:ok, data} <- validate_and_cast(ap_data, verified_nick) do
      olduser = olduser || User.get_cached_by_ap_id(data.ap_id)

      if !olduser || olduser.nickname != data.nickname do
        maybe_handle_clashing_nickname(data)
      end

      data = maybe_update_follow_information(data)

      with {:ok, newuser} <- insert_or_update(olduser, data) do
        enqueue_pin_fetches(data)
        {:ok, newuser}
      end
    end
  end

  defp discover_nick_from_actor_data(data) do
    case WebFinger.Finger.finger_actor(data) do
      {:ok, nil} ->
        Logger.debug("No WebFinger found for #{data["id"]}; using fallback")
        nil

      {:ok, nick} ->
        nick

      {:error, error} ->
        Logger.error(
          "Invalid WebFinger for #{data["id"]}; spoof attempt or just misconfiguration? Using safe fallback: #{inspect(error)}"
        )

        nil
    end
  end

  defp needs_nick_update(%{"webfinger" => "acct:" <> nick}, nick), do: false
  defp needs_nick_update(%{"webfinger" => nick}, nick), do: false

  defp needs_nick_update(%{"preferredUsername" => name}, oldnick) when is_binary(name) do
    String.starts_with?(oldnick, name <> "@")
  end

  defp needs_nick_update(ap_data, oldnick) do
    ap_nick = ap_data["webfinger"] || ap_data["preferredUsername"]
    (!oldnick && ap_nick) || (oldnick && !ap_nick)
  end

  defp refreshed_nick(ap_data, olduser) do
    if Config.get!([Pleroma.Web.WebFinger, :update_nickname_on_user_fetch]) ||
         !olduser || needs_nick_update(ap_data, olduser.nickname) do
      discover_nick_from_actor_data(ap_data)
    else
      olduser.nickname
    end
  end

  defp refresh_or_fetch_from_ap_id(ap_id, olduser) do
    with {:ok, data} <- APFetcher.fetch_and_contain_remote_object_from_id(ap_id),
         # if AP id somehow changed on refetch, discard old info
         verified_olduser <- (olduser && olduser.ap_id == data["id"] && olduser) || nil,
         verified_nick <- refreshed_nick(data, verified_olduser) do
      make_user_from_apdata_and_nick(data, verified_nick, verified_olduser)
    else
      # If this has been deleted, only log a debug and not an error
      {:error, {"Object has been deleted", _, _} = e} ->
        Logger.debug("User was explicitly deleted #{ap_id}, #{inspect(e)}")
        {:error, :not_found}

      {:reject, _reason} = e ->
        {:error, e}

      {:error, e} ->
        {:error, e}
    end
  end

  def make_user_from_ap_id(ap_id), do: refresh_or_fetch_from_ap_id(ap_id, nil)

  def refetch_user(%User{ap_id: ap_id} = u), do: refresh_or_fetch_from_ap_id(ap_id, u)

  def make_user_from_nickname(nickname) do
    case WebFinger.Finger.finger_mention(nickname) do
      {:ok, handle, actor_data} ->
        make_user_from_apdata_and_nick(actor_data, handle)

      error ->
        error
    end
  end

  def update_user_with_apdata(%{"id" => ap_id} = new_ap_data) do
    with %User{} = old_user <- User.get_cached_by_ap_id(ap_id) do
      new_nick = refreshed_nick(new_ap_data, old_user)
      make_user_from_apdata_and_nick(new_ap_data, new_nick, old_user)
    else
      nil ->
        Logger.warning("Cannot update unknown user #{ap_id}")
        {:error, :not_found}
    end
  end
end
