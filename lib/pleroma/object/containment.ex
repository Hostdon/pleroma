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

  alias Pleroma.Web.ActivityPub.Transmogrifier

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

  defp compare_uris_exact(uri, uri), do: :ok

  defp compare_uris_exact(%URI{} = id, %URI{} = other),
    do: compare_uris_exact(URI.to_string(id), URI.to_string(other))

  defp compare_uris_exact(id_uri, other_uri)
       when is_binary(id_uri) and is_binary(other_uri) do
    norm_id = String.replace_suffix(id_uri, "/", "")
    norm_other = String.replace_suffix(other_uri, "/", "")
    if norm_id == norm_other, do: :ok, else: :error
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
  Check whether the fetch URL (after redirects) exactly (sans tralining slash) matches either
  the canonical ActivityPub id or the objects url field (for display URLs from *key and Mastodon)

  Since this is meant to be used for fetches, anonymous or transient objects are not accepted here.
  """
  def contain_id_to_fetch(url, %{"id" => id} = data) when is_binary(id) do
    with {:id, :error} <- {:id, compare_uris_exact(id, url)},
         # "url" can be a "Link" object and this is checked before full normalisation
         display_url <- Transmogrifier.fix_url(data)["url"],
         true <- display_url != nil do
      compare_uris_exact(display_url, url)
    else
      {:id, :ok} -> :ok
      _ -> :error
    end
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
end
