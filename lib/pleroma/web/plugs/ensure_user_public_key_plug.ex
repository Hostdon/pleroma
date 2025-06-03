defmodule Pleroma.Web.Plugs.EnsureUserPublicKeyPlug do
  @moduledoc """
  This plug will attempt to pull in a user's public key if we do not have it.
  We _should_ be able to request the URL from the key URL...
  """

  alias Pleroma.User

  def init(options), do: options

  def call(conn, _opts) do
    key_id = key_id_from_conn(conn)

    unless is_nil(key_id) do
      User.SigningKey.get_or_fetch_by_key_id(key_id)
      # now we SHOULD have the user that owns the key locally. maybe.
      # if we don't, we'll error out when we try to validate.
    end

    conn
  end

  defp key_id_from_conn(conn) do
    case HTTPSignatures.signature_for_conn(conn) do
      %{"keyId" => key_id} when is_binary(key_id) ->
        key_id

      _ ->
        nil
    end
  end
end
