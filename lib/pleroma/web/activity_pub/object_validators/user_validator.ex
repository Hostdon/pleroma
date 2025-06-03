# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UserValidator do
  @moduledoc """
  Checks whether ActivityPub data represents a valid user

  Users don't go through the same ingest pipeline like activities or other objects.
  To ensure this can only match a user and no users match in the other pipeline,
  this is a separate from the generic ObjectValidator.
  """

  @behaviour Pleroma.Web.ActivityPub.ObjectValidator.Validating

  alias Pleroma.Object.Containment

  require Pleroma.Constants

  @impl true
  def validate(object, meta)

  def validate(%{"type" => type, "id" => _id} = data, meta)
      when type in Pleroma.Constants.actor_types() do
    with :ok <- validate_pubkey(data),
         :ok <- validate_inbox(data),
         :ok <- contain_collection_origin(data) do
      {:ok, data, meta}
    else
      {:error, e} -> {:error, e}
      e -> {:error, e}
    end
  end

  def validate(_, _), do: {:error, "Not a user object"}

  defp validate_pubkey(%{
         "id" => user_id,
         "publicKey" => %{"id" => pk_id, "publicKeyPem" => _key}
       }) do
    with {_, true} <- {:user, is_binary(user_id)},
         {_, true} <- {:key, is_binary(pk_id)},
         :ok <- Containment.contain_key_user(pk_id, user_id) do
      :ok
    else
      {:user, _} -> {:error, "Invalid user id: #{inspect(user_id)}"}
      {:key, _} -> {:error, "Invalid key id: #{inspect(pk_id)}"}
      :error -> {:error, "Problematic actor-key pairing: #{user_id} - #{pk_id}"}
    end
  end

  # pubkey is optional atm
  defp validate_pubkey(_data), do: :ok

  defp validate_inbox(%{"id" => id, "inbox" => inbox}) do
    case Containment.same_origin(id, inbox) do
      :ok -> :ok
      :error -> {:error, "Inbox on different doamin"}
    end
  end

  defp validate_inbox(_), do: {:error, "No inbox"}

  defp check_field_value(%{"id" => id} = _data, value) do
    Containment.same_origin(id, value)
  end

  defp maybe_check_field(data, field) do
    with val when val != nil <- data[field],
         :ok <- check_field_value(data, val) do
      :ok
    else
      nil -> :ok
      _ -> {:error, "#{field} on different domain"}
    end
  end

  defp contain_collection_origin(data) do
    Enum.reduce(["followers", "following", "featured"], :ok, fn
      field, :ok -> maybe_check_field(data, field)
      _, error -> error
    end)
  end
end
