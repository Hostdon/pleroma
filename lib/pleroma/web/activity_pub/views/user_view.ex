# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.UserView do
  use Pleroma.Web, :view

  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.CollectionViewHelper
  alias Pleroma.Web.ActivityPub.ObjectView
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.WebFinger

  require Ecto.Query
  require Pleroma.Web.ActivityPub.Transmogrifier

  defp maybe_put(map, _, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  def render("endpoints.json", %{user: %User{local: true} = _user}) do
    %{
      "oauthAuthorizationEndpoint" => url(~p"/oauth/authorize"),
      "oauthRegistrationEndpoint" => url(~p"/api/v1/apps"),
      "oauthTokenEndpoint" => url(~p"/oauth/token"),
      "sharedInbox" => url(~p"/inbox")
    }
  end

  def render("endpoints.json", _), do: %{}

  def render("service.json", %{user: user}) do
    {:ok, public_key} = User.SigningKey.public_key_pem(user)

    endpoints = render("endpoints.json", %{user: user})

    %{
      "id" => user.ap_id,
      "type" => "Application",
      "inbox" => user.inbox,
      "outbox" => user.outbox,
      "name" => "Akkoma",
      "summary" =>
        "An internal service actor for this Akkoma instance.  No user-serviceable parts inside.",
      "url" => user.ap_id,
      "manuallyApprovesFollowers" => false,
      "publicKey" => %{
        "id" => User.SigningKey.local_key_id(user.ap_id),
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => endpoints,
      "invisible" => User.invisible?(user)
    }
    |> maybe_put("following", user.following_address)
    |> maybe_put("followers", user.follower_address)
    |> maybe_put("preferredUsername", user.nickname)
    |> maybe_put_webfinger(user)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("user.json", %{user: %User{actor_type: "Application"} = user}),
    do: render("service.json", %{user: user})

  def render("user.json", %{user: user}) do
    public_key =
      case User.SigningKey.public_key_pem(user) do
        {:ok, public_key} -> public_key
        _ -> nil
      end

    user = User.sanitize_html(user)

    endpoints = render("endpoints.json", %{user: user})

    emoji_tags = Transmogrifier.take_emoji_tags(user)

    fields = Enum.map(user.fields, &Map.put(&1, "type", "PropertyValue"))

    capabilities = %{}

    %{
      "id" => user.ap_id,
      "type" => user.actor_type,
      "following" => user.following_address,
      "followers" => user.follower_address,
      "inbox" => user.inbox,
      "outbox" => user.outbox,
      "featured" => user.featured_address,
      "preferredUsername" => user.nickname,
      "name" => user.name,
      "summary" => user.bio,
      "url" => user.uri || user.ap_id,
      "manuallyApprovesFollowers" => user.is_locked,
      "publicKey" => %{
        "id" => User.SigningKey.local_key_id(user.ap_id),
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      "endpoints" => endpoints,
      "attachment" => fields,
      "tag" => emoji_tags,
      # Note: key name is indeed "discoverable" (not an error)
      "discoverable" => user.is_discoverable,
      "capabilities" => capabilities,
      "alsoKnownAs" => user.also_known_as
    }
    |> maybe_put_webfinger(user)
    |> Map.merge(
      maybe_make_image(&User.avatar_url/2, User.image_description(user.avatar), "icon", user)
    )
    |> Map.merge(
      maybe_make_image(&User.banner_url/2, User.image_description(user.banner), "image", user)
    )
    # Yes, the key is named ...Url eventhough it is a whole 'Image' object
    |> Map.merge(
      maybe_insert_image(
        "backgroundUrl",
        User.background_url(user),
        User.image_description(user.background)
      )
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  # For unauthenticated requests when authfetch is enabled.
  # Still serve the key and the bare minimum of required fields
  # to avoid being stuck in an infinite "cannot verify" loop with remotes.
  def render("stripped_user.json", %{user: user}) do
    {:ok, public_key} = User.SigningKey.public_key_pem(user)

    %{
      "id" => user.ap_id,
      "publicKey" => %{
        "id" => User.SigningKey.key_id_of_local_user(user),
        "owner" => user.ap_id,
        "publicKeyPem" => public_key
      },
      # REQUIRED fields per AP spec
      "inbox" => user.inbox,
      "outbox" => user.outbox,
      # allow type-based processing
      "type" => user.actor_type,
      # since Mastodon requires a WebFinger address for all users, this seems like a good idea
      "preferredUsername" => user.nickname
    }
    |> maybe_put_webfinger(user)
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user, page: page} = opts) do
    showing_items = (opts[:for] && opts[:for] == user) || !user.hide_follows
    showing_count = showing_items || !user.hide_follows_count

    total =
      if showing_count do
        user.following_count
      else
        0
      end

    following =
      if showing_items and total > 0 do
        User.get_friends_query(user)
        |> Ecto.Query.select([u], u.ap_id)
        |> Repo.all()
      else
        []
      end

    CollectionViewHelper.collection_page_offset(
      following,
      user.following_address,
      page,
      showing_items,
      total
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("following.json", %{user: user} = opts) do
    showing_items = (opts[:for] && opts[:for] == user) || !user.hide_follows
    showing_count = showing_items || !user.hide_follows_count

    total = showing_count && user.following_count

    following =
      if showing_items && total > 0 do
        User.get_friends_query(user)
        |> Ecto.Query.select([u], u.ap_id)
        |> Repo.all()
      else
        []
      end

    first_page =
      showing_items &&
        CollectionViewHelper.collection_page_offset(
          following,
          user.following_address,
          1,
          !user.hide_follows
        )

    CollectionViewHelper.collection_root_ordered(
      user.following_address,
      total,
      first_page
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user, page: page} = opts) do
    showing_items = (opts[:for] && opts[:for] == user) || !user.hide_followers
    showing_count = showing_items || !user.hide_followers_count

    total =
      if showing_count do
        user.follower_count
      else
        0
      end

    followers =
      if showing_items and total > 0 do
        User.get_followers_query(user)
        |> Ecto.Query.select([u], u.ap_id)
        |> Repo.all()
      else
        []
      end

    CollectionViewHelper.collection_page_offset(
      followers,
      user.follower_address,
      page,
      showing_items,
      total
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("followers.json", %{user: user} = opts) do
    showing_items = (opts[:for] && opts[:for] == user) || !user.hide_followers
    showing_count = showing_items || !user.hide_followers_count

    total = showing_count && user.follower_count

    followers =
      if showing_items and total > 0 do
        User.get_followers_query(user)
        |> Ecto.Query.select([u], u.ap_id)
        |> Repo.all()
      else
        []
      end

    first_page =
      showing_items &&
        CollectionViewHelper.collection_page_offset(
          followers,
          user.follower_address,
          1,
          showing_items,
          total
        )

    CollectionViewHelper.collection_root_ordered(
      user.follower_address,
      total,
      first_page
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("activity_collection.json", %{iri: iri}) do
    CollectionViewHelper.collection_root_ordered(
      iri,
      false,
      "#{iri}?page=true"
    )
    |> Map.merge(Utils.make_json_ld_header())
  end

  def render("activity_collection_page.json", %{
        activities: activities,
        pagination: pagination
      }) do
    display_items =
      Enum.map(activities, fn activity ->
        {:ok, data} = Transmogrifier.prepare_outgoing(activity.data)
        data
      end)

    CollectionViewHelper.collection_page_keyset(display_items, pagination)
  end

  def render("featured.json", %{
        user: %{featured_address: featured_address, pinned_objects: pinned_objects}
      }) do
    objects =
      pinned_objects
      |> Enum.sort_by(fn {_, pinned_at} -> pinned_at end, &>=/2)
      |> Enum.map(fn {id, _} ->
        ObjectView.render("object.json", %{object: Object.get_cached_by_ap_id(id)})
      end)

    %{
      "id" => featured_address,
      "type" => "OrderedCollection",
      "orderedItems" => objects,
      "totalItems" => length(objects)
    }
    |> Map.merge(Utils.make_json_ld_header())
  end

  defp maybe_put_webfinger(%{"preferredUsername" => username} = data, %{local: true}) do
    # FEP-2c59 entry for local users
    webfinger_domain = WebFinger.Schema.domain()
    Map.put(data, "webfinger", "#{username}@#{webfinger_domain}")
  end

  defp maybe_put_webfinger(data, _), do: data

  defp maybe_make_image(func, description, key, user) do
    image = func.(user, no_default: true)
    maybe_insert_image(key, image, description)
  end

  defp maybe_insert_image(key, image, description) do
    if image do
      %{
        key =>
          %{
            "type" => "Image",
            "url" => image
          }
          |> maybe_put("name", description)
      }
    else
      %{}
    end
  end
end
