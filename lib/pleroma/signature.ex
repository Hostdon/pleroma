# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Signature do
  @behaviour HTTPSignatures.Adapter

  alias Pleroma.User
  alias Pleroma.User.SigningKey
  require Logger

  def fetch_public_key(conn) do
    with {_, %{"keyId" => kid}} <- {:keyid, HTTPSignatures.signature_for_conn(conn)},
         {_, {:ok, %SigningKey{} = sk}, _} <-
           {:fetch, SigningKey.get_or_fetch_by_key_id(kid), kid},
         {_, {:ok, decoded_key}} <- {:decode, SigningKey.public_key_decoded(sk)} do
      {:ok, decoded_key}
    else
      {:fetch, error, kid} ->
        Logger.error("Failed to acquire key from signature: #{kid} #{inspect(error)}")
        {:error, {:fetch, error}}

      e ->
        {:error, e}
    end
  end

  def refetch_public_key(conn) do
    with {_, %{"keyId" => kid}} <- {:keyid, HTTPSignatures.signature_for_conn(conn)},
         {_, {:ok, %SigningKey{} = sk}, _} <- {:fetch, SigningKey.refresh_by_key_id(kid), kid},
         {_, {:ok, decoded_key}} <- {:decode, SigningKey.public_key_decoded(sk)} do
      {:ok, decoded_key}
    else
      {:fetch, {:error, :too_young}, kid} ->
        Logger.debug("Refusing to refetch recently updated key: #{kid}")
        {:error, {:fetch, :too_young}}

      {:fetch, {:error, :unknown}, kid} ->
        Logger.warning("Attempted to refresh unknown key; this should not happen: #{kid}")
        {:error, {:fetch, :unknown}}

      {:fetch, error, kid} ->
        Logger.error("Failed to refresh stale key from signature: #{kid} #{inspect(error)}")
        {:error, {:fetch, error}}

      e ->
        {:error, e}
    end
  end

  def sign(%User{} = user, headers) do
    with {:ok, private_key} <- SigningKey.private_key(user) do
      HTTPSignatures.sign(private_key, SigningKey.local_key_id(user.ap_id), headers)
    end
  end

  def signed_date, do: signed_date(NaiveDateTime.utc_now())

  def signed_date(%NaiveDateTime{} = date) do
    Timex.lformat!(date, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT", "en")
  end
end
