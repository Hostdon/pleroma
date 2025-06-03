# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.Containment do
  @moduledoc """
  This module contains some useful functions for containing objects to specific
  origins and determining those origins.  They previously lived in the
  ActivityPub `Transmogrifier` module.

  Object containment is an important step in validating remote objects to prevent
  spoofing, therefore removal of object containment functions is NOT recommended.
  """

  def get_actor(%{"actor" => actor}) when is_binary(actor) do
    actor
  end

  def get_actor(%{"actor" => actor}) when is_list(actor) do
    if is_binary(Enum.at(actor, 0)) do
      Enum.at(actor, 0)
    else
      Enum.find(actor, fn %{"type" => type} -> type in ["Person", "Service", "Application"] end)
      |> Map.get("id")
    end
  end

  def get_actor(%{"actor" => %{"id" => id}}) when is_bitstring(id) do
    id
  end

  def get_actor(%{"actor" => nil, "attributedTo" => actor}) when not is_nil(actor) do
    get_actor(%{"actor" => actor})
  end

  def get_object(%{"object" => id}) when is_binary(id) do
    id
  end

  def get_object(%{"object" => %{"id" => id}}) when is_binary(id) do
    id
  end

  def get_object(_) do
    nil
  end

  defp compare_uris(%URI{host: host} = _id_uri, %URI{host: host} = _other_uri), do: :ok
  defp compare_uris(_id_uri, _other_uri), do: :error

  defp uri_strip_slash(%URI{path: path} = uri) when is_binary(path),
    do: %{uri | path: String.replace_suffix(path, "/", "")}

  defp uri_strip_slash(uri), do: uri

  # domain names are case-insensitive per spec (other parts of URIs aren’t necessarily)
  defp uri_normalise_host(%URI{host: host} = uri) when is_binary(host),
    do: %{uri | host: String.downcase(host, :ascii)}

  defp uri_normalise_host(uri), do: uri

  defp compare_uri_identities(uri, uri), do: :ok

  defp compare_uri_identities(id_uri, other_uri) when is_binary(id_uri) and is_binary(other_uri),
    do: compare_uri_identities(URI.parse(id_uri), URI.parse(other_uri))

  defp compare_uri_identities(%URI{} = id, %URI{} = other) do
    normid =
      %{id | fragment: nil}
      |> uri_strip_slash()
      |> uri_normalise_host()

    normother =
      %{other | fragment: nil}
      |> uri_strip_slash()
      |> uri_normalise_host()

    # Conversion back to binary avoids issues from non-normalised deprecated authority field
    if URI.to_string(normid) == URI.to_string(normother) do
      :ok
    else
      :error
    end
  end

  @doc """
  Checks whether an URL to fetch from is from the local server.

  We never want to fetch from ourselves; if it’s not in the database
  it can’t be authentic and must be a counterfeit.
  """
  def contain_local_fetch(id) do
    case compare_uris(URI.parse(id), Pleroma.Web.Endpoint.struct_url()) do
      :ok -> :error
      _ -> :ok
    end
  end

  @doc """
  Checks that an imported AP object's actor matches the host it came from.
  """
  def contain_origin(_id, %{"actor" => nil}), do: :error

  def contain_origin(id, %{"actor" => _actor} = params) do
    id_uri = URI.parse(id)
    actor_uri = URI.parse(get_actor(params))

    compare_uris(actor_uri, id_uri)
  end

  def contain_origin(id, %{"attributedTo" => actor} = params),
    do: contain_origin(id, Map.put(params, "actor", actor))

  def contain_origin(_id, _data), do: :ok

  @doc """
  Check whether the fetch URL (after redirects) is the
  same location the canonical ActivityPub id points to.

  Since this is meant to be used for fetches, anonymous or transient objects are not accepted here.
  """
  def contain_id_to_fetch(url, %{"id" => id}) when is_binary(id) do
    compare_uri_identities(url, id)
  end

  def contain_id_to_fetch(_url, _data), do: :error

  @doc """
  Check whether the object id is from the same host as another id
  """
  def contain_origin_from_id(id, %{"id" => other_id} = _params) when is_binary(other_id) do
    id_uri = URI.parse(id)
    other_uri = URI.parse(other_id)

    compare_uris(id_uri, other_uri)
  end

  # Mastodon pin activities don't have an id, so we check the object field, which will be pinned.
  def contain_origin_from_id(id, %{"object" => object}) when is_binary(object) do
    id_uri = URI.parse(id)
    object_uri = URI.parse(object)

    compare_uris(id_uri, object_uri)
  end

  def contain_origin_from_id(_id, _data), do: :error

  def contain_child(%{"object" => %{"id" => id, "attributedTo" => _} = object}),
    do: contain_origin(id, object)

  def contain_child(_), do: :ok

  @doc "Checks whether two URIs belong to the same domain"
  def same_origin(id1, id2) do
    uri1 = URI.parse(id1)
    uri2 = URI.parse(id2)

    compare_uris(uri1, uri2)
  end

  @doc """
  Checks whether a key_id - owner_id pair are acceptable.

  While in theory keys and actors on different domain could be verified
  by fetching both and checking the links on both ends (if different at all),
  this requires extra fetches and there are no known implementations with split
  actor and key domains, thus atm this simply requires same domain.
  """
  def contain_key_user(key_id, user_id) do
    same_origin(key_id, user_id)
  end
end
