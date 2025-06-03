# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Object.Fetcher do
  alias Pleroma.HTTP
  alias Pleroma.Instances
  alias Pleroma.Maps
  alias Pleroma.Object
  alias Pleroma.Object.Containment
  alias Pleroma.Repo
  alias Pleroma.Signature
  alias Pleroma.Web.ActivityPub.InternalFetchActor
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.Federator

  require Logger
  require Pleroma.Constants

  @moduledoc """
  This module deals with correctly fetching Acitivity Pub objects in a safe way.

  The core function is `fetch_and_contain_remote_object_from_id/1` which performs
  the actual fetch and common safety and authenticity checks. Other `fetch_*`
  function use the former and perform some additional tasks
  """

  @mix_env Mix.env()

  defp touch_changeset(changeset) do
    updated_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    Ecto.Changeset.put_change(changeset, :updated_at, updated_at)
  end

  defp maybe_reinject_internal_fields(%{data: %{} = old_data}, new_data) do
    has_history? = fn
      %{"formerRepresentations" => %{"orderedItems" => list}} when is_list(list) -> true
      _ -> false
    end

    internal_fields = Map.take(old_data, Pleroma.Constants.object_internal_fields())

    remote_history_exists? = has_history?.(new_data)

    # If the remote history exists, we treat that as the only source of truth.
    new_data =
      if has_history?.(old_data) and not remote_history_exists? do
        Map.put(new_data, "formerRepresentations", old_data["formerRepresentations"])
      else
        new_data
      end

    # If the remote does not have history information, we need to manage it ourselves
    new_data =
      if not remote_history_exists? do
        changed? =
          Pleroma.Constants.status_updatable_fields()
          |> Enum.any?(fn field -> Map.get(old_data, field) != Map.get(new_data, field) end)

        %{updated_object: updated_object} =
          new_data
          |> Object.Updater.maybe_update_history(old_data,
            updated: changed?,
            use_history_in_new_object?: false
          )

        updated_object
      else
        new_data
      end

    Map.merge(new_data, internal_fields)
  end

  defp maybe_reinject_internal_fields(_, new_data), do: new_data

  @spec reinject_object(struct(), map()) :: {:ok, Object.t()} | {:error, any()}
  defp reinject_object(%Object{data: %{"type" => "Question"}} = object, new_data) do
    Logger.debug("Reinjecting object #{new_data["id"]}")

    with data <- maybe_reinject_internal_fields(object, new_data),
         {:ok, data, _} <- ObjectValidator.validate(data, %{}),
         changeset <- Object.change(object, %{data: data}),
         changeset <- touch_changeset(changeset),
         {:ok, object} <- Repo.insert_or_update(changeset),
         {:ok, object} <- Object.set_cache(object) do
      {:ok, object}
    else
      e ->
        Logger.error("Error while processing object: #{inspect(e)}")
        {:error, e}
    end
  end

  defp reinject_object(%Object{} = object, new_data) do
    Logger.debug("Reinjecting object #{new_data["id"]}")

    with new_data <- Transmogrifier.fix_object(new_data),
         data <- maybe_reinject_internal_fields(object, new_data),
         changeset <- Object.change(object, %{data: data}),
         changeset <- touch_changeset(changeset),
         {:ok, object} <- Repo.insert_or_update(changeset),
         {:ok, object} <- Object.set_cache(object) do
      {:ok, object}
    else
      e ->
        Logger.error("Error while processing object: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc "Assumes object already is in our database and refetches from remote to update (e.g. for polls)"
  def refetch_object(%Object{data: %{"id" => id}} = object) do
    with {:local, false} <- {:local, Object.local?(object)},
         {:ok, new_data} <- fetch_and_contain_remote_object_from_id(id, true),
         {:id, true} <- {:id, new_data["id"] == id},
         {:ok, object} <- reinject_object(object, new_data) do
      {:ok, object}
    else
      {:local, true} -> {:ok, object}
      {:id, false} -> {:error, :id_mismatch}
      e -> {:error, e}
    end
  end

  @doc """
    Fetches a new object and puts it through the processing pipeline for inbound objects

    Note: will also insert a fake Create activity, since atm we internally
    need everything to be traced back to a Create activity.
  """
  def fetch_object_from_id(id, options \\ []) do
    with %URI{} = uri <- URI.parse(id),
         # let's check the URI is even vaguely valid first
         {:valid_uri_scheme, true} <-
           {:valid_uri_scheme, uri.scheme == "http" or uri.scheme == "https"},
         # If we have instance restrictions, apply them here to prevent fetching from unwanted instances
         {:mrf_reject_check, {:ok, nil}} <-
           {:mrf_reject_check, Pleroma.Web.ActivityPub.MRF.SimplePolicy.check_reject(uri)},
         {:mrf_accept_check, {:ok, _}} <-
           {:mrf_accept_check, Pleroma.Web.ActivityPub.MRF.SimplePolicy.check_accept(uri)},
         {_, nil} <- {:fetch_object, Object.get_cached_by_ap_id(id)},
         {_, true} <- {:allowed_depth, Federator.allowed_thread_distance?(options[:depth])},
         {_, {:ok, data}} <- {:fetch, fetch_and_contain_remote_object_from_id(id)},
         {_, nil} <- {:normalize, Object.normalize(data, fetch: false)},
         params <- prepare_activity_params(data),
         {_, {:ok, activity}} <-
           {:transmogrifier, Transmogrifier.handle_incoming(params, options)},
         {_, _data, %Object{} = object} <-
           {:object, data, Object.normalize(activity, fetch: false)} do
      {:ok, object}
    else
      {:allowed_depth, false} = e ->
        log_fetch_error(id, e)
        {:error, :allowed_depth}

      {:valid_uri_scheme, _} = e ->
        log_fetch_error(id, e)
        {:error, :invalid_uri_scheme}

      {:mrf_reject_check, _} = e ->
        log_fetch_error(id, e)
        {:reject, :mrf}

      {:mrf_accept_check, _} = e ->
        log_fetch_error(id, e)
        {:reject, :mrf}

      {:containment, reason} = e ->
        log_fetch_error(id, e)
        {:error, reason}

      {:transmogrifier, {:error, {:reject, reason}}} = e ->
        log_fetch_error(id, e)
        {:reject, reason}

      {:transmogrifier, {:reject, reason}} = e ->
        log_fetch_error(id, e)
        {:reject, reason}

      {:transmogrifier, reason} = e ->
        log_fetch_error(id, e)
        {:error, reason}

      {:object, data, nil} ->
        reinject_object(%Object{}, data)

      {:normalize, object = %Object{}} ->
        {:ok, object}

      {:fetch_object, %Object{} = object} ->
        {:ok, object}

      {:fetch, {:error, reason}} = e ->
        log_fetch_error(id, e)
        {:error, reason}

      e ->
        log_fetch_error(id, e)
        {:error, e}
    end
  end

  defp log_fetch_error(id, error) do
    Logger.metadata(object: id)
    Logger.error("Object rejected while fetching #{id} #{inspect(error)}")
  end

  defp prepare_activity_params(data) do
    %{
      "type" => "Create",
      # Should we seriously keep this attributedTo thing?
      "actor" => data["actor"] || data["attributedTo"],
      "object" => data
    }
    |> Maps.put_if_present("to", data["to"])
    |> Maps.put_if_present("cc", data["cc"])
    |> Maps.put_if_present("bto", data["bto"])
    |> Maps.put_if_present("bcc", data["bcc"])
  end

  defp make_signature(id, date) do
    uri = URI.parse(id)

    signature =
      InternalFetchActor.get_actor()
      |> Signature.sign(%{
        "(request-target)": "get #{uri.path}",
        host: uri.host,
        date: date
      })

    {"signature", signature}
  end

  defp sign_fetch(headers, id, date) do
    if Pleroma.Config.get([:activitypub, :sign_object_fetches]) do
      [make_signature(id, date) | headers]
    else
      headers
    end
  end

  defp maybe_date_fetch(headers, date) do
    if Pleroma.Config.get([:activitypub, :sign_object_fetches]) do
      [{"date", date} | headers]
    else
      headers
    end
  end

  @doc """
  Fetches arbitrary remote object and performs basic safety and authenticity checks.
  When the fetch URL is known to already be a canonical AP id, checks are stricter.
  """
  def fetch_and_contain_remote_object_from_id(id, is_ap_id \\ false)

  def fetch_and_contain_remote_object_from_id(%{"id" => id}, is_ap_id),
    do: fetch_and_contain_remote_object_from_id(id, is_ap_id)

  def fetch_and_contain_remote_object_from_id(id, is_ap_id) when is_binary(id) do
    Logger.debug("Fetching object #{id} via AP [ap_id=#{is_ap_id}]")

    fetch_and_contain_remote_ap_doc(
      id,
      is_ap_id,
      fn final_uri, data -> {Containment.contain_id_to_fetch(final_uri, data), data["id"]} end
    )
  end

  def fetch_and_contain_remote_object_from_id(_id, _is_ap_id),
    do: {:error, :invalid_id}

  def fetch_and_contain_remote_key(id) do
    Logger.debug("Fetching remote actor key #{id}")

    fetch_and_contain_remote_ap_doc(
      id,
      # key IDs are alwas AP IDs which should resolve directly and exactly
      true,
      fn
        final_uri, %{"id" => user_id, "publicKey" => %{"id" => key_id}} ->
          # For non-fragment keys as used e.g. by GTS, the "id" won't match the fetch URI,
          # but the key ID will. Thus do NOT strict check the top-lelve id, but byte-exact
          # check the key ID (since for later lookups we need byte-exact matches).
          # This relies on fetching already enforcing a domain match for toplevel id and host
          with :ok <- Containment.contain_key_user(key_id, user_id),
               true <- key_id == final_uri do
            {:ok, key_id}
          else
            _ -> {:error, key_id}
          end

        final_uri,
        %{"type" => "CryptographicKey", "id" => key_id, "owner" => user_id, "publicKeyPem" => _} ->
          # XXX: refactor into separate function isntead of duplicating
          with :ok <- Containment.contain_key_user(key_id, user_id),
               true <- key_id == final_uri do
            {:ok, key_id}
          else
            _ -> {:error, nil}
          end

        _, _ ->
          {:error, nil}
      end
    )
  end

  # Fetches an AP document and performing variable security checks on it.
  #
  # Note that the received documents "id" matching the final host domain
  # is always enforced before the custom ID check runs.
  @spec fetch_and_contain_remote_ap_doc(
          String.t(),
          boolean(),
          (String.t(), Map.t() -> {:ok | :error, String.t() | term()})
        ) :: {:ok, Map.t()} | {:reject, term()} | {:error, term()}
  defp fetch_and_contain_remote_ap_doc(id, is_ap_id, verify_id) do
    Logger.debug("Dereferencing AP doc #{}")

    with {:valid_uri_scheme, true} <- {:valid_uri_scheme, String.starts_with?(id, "http")},
         %URI{} = uri <- URI.parse(id),
         {:mrf_reject_check, {:ok, nil}} <-
           {:mrf_reject_check, Pleroma.Web.ActivityPub.MRF.SimplePolicy.check_reject(uri)},
         {:mrf_accept_check, {:ok, _}} <-
           {:mrf_accept_check, Pleroma.Web.ActivityPub.MRF.SimplePolicy.check_accept(uri)},
         {:local_fetch, :ok} <- {:local_fetch, Containment.contain_local_fetch(id)},
         {:ok, final_id, body} <- get_object(id),
         # a canonical ID shouldn't be a redirect
         true <- !is_ap_id || final_id == id,
         {:ok, data} <- safe_json_decode(body),
         {_, :ok} <- {:containment, Containment.contain_origin(final_id, data)},
         {_, {:ok, _}} <- {:strict_id, verify_id.(final_id, data)} do
      unless Instances.reachable?(final_id) do
        Instances.set_reachable(final_id)
      end

      {:ok, data}
    else
      # E.g.  Mastodon and *key serve the AP object directly under their display URLs without
      # redirecting to their canonical location first, thus ids will expectedly differ.
      # Similarly keys, either use a fragment ID and are a subobjects or a distinct ID
      # but for compatibility are still a subobject presenting their owning actors ID at the toplevel.
      # Refetching _once_ from the listed id, should yield a strict match afterwards.
      {:strict_id, {_error, ap_id}} = e ->
        if !is_ap_id and is_binary(ap_id) do
          fetch_and_contain_remote_ap_doc(ap_id, true, verify_id)
        else
          log_fetch_error(id, e)
          {:error, :id_mismatch}
        end

      {:mrf_reject_check, _} = e ->
        log_fetch_error(id, e)
        {:reject, :mrf}

      {:mrf_accept_check, _} = e ->
        log_fetch_error(id, e)
        {:reject, :mrf}

      {:valid_uri_scheme, _} = e ->
        log_fetch_error(id, e)
        {:error, :invalid_uri_scheme}

      {:local_fetch, _} = e ->
        log_fetch_error(id, e)
        {:error, :local_resource}

      {:containment, reason} ->
        log_fetch_error(id, reason)
        {:error, {:containment, reason}}

      {:error, e} ->
        {:error, e}

      e ->
        {:error, e}
    end
  end

  # HOPEFULLY TEMPORARY
  # Basically none of our Tesla mocks in tests set the (supposed to
  # exist for Tesla proper) url parameter for their responses
  # causing almost every fetch in test to fail otherwise
  if @mix_env == :test do
    defp get_final_id(nil, initial_url), do: initial_url
    defp get_final_id("", initial_url), do: initial_url
  end

  defp get_final_id(final_url, _intial_url) do
    final_url
  end

  @doc "Do NOT use; only public for use in tests"
  def get_object(id) do
    date = Pleroma.Signature.signed_date()

    headers =
      [
        # The first is required by spec, the second provided as a fallback for buggy implementations
        {"accept", "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""},
        {"accept", "application/activity+json"}
      ]
      |> maybe_date_fetch(date)
      |> sign_fetch(id, date)

    with {:ok, %{body: body, status: code, headers: headers, url: final_url}}
         when code in 200..299 <-
           HTTP.Backoff.get(id, headers),
         {:has_content_type, {_, content_type}} <-
           {:has_content_type, List.keyfind(headers, "content-type", 0)},
         {:parse_content_type, {:ok, "application", subtype, type_params}} <-
           {:parse_content_type, Plug.Conn.Utils.media_type(content_type)} do
      final_id = get_final_id(final_url, id)

      case {subtype, type_params} do
        {"activity+json", _} ->
          {:ok, final_id, body}

        {"ld+json", %{"profile" => profiles}} ->
          if "https://www.w3.org/ns/activitystreams" in String.split(profiles) do
            {:ok, final_id, body}
          else
            {:error, {:content_type, content_type}}
          end

        _ ->
          {:error, {:content_type, content_type}}
      end
    else
      {:ok, %{status: code}} when code in [401, 403] ->
        {:error, :forbidden}

      {:ok, %{status: code}} when code in [404, 410] ->
        {:error, :not_found}

      {:error, e} ->
        {:error, e}

      {:has_content_type, _} ->
        {:error, {:content_type, nil}}

      {:parse_content_type, e} ->
        {:error, {:content_type, e}}

      e ->
        {:error, e}
    end
  end

  defp safe_json_decode(nil), do: {:ok, nil}
  defp safe_json_decode(json), do: Jason.decode(json)
end
