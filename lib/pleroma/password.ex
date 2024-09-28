defmodule Pleroma.Password do
  @moduledoc """
  This module handles password hashing and verification.
  It will delegate to the appropriate module based on the password hash.
  It also handles upgrading of password hashes.
  """

  alias Pleroma.User
  alias Pleroma.Password.Pbkdf2
  require Logger

  @hashing_module Argon2

  @spec hash_pwd_salt(String.t()) :: String.t()
  defdelegate hash_pwd_salt(pass), to: @hashing_module

  @spec checkpw(String.t(), String.t()) :: boolean()
  def checkpw(password, "$2" <> _ = password_hash) do
    # Handle bcrypt passwords for Mastodon migration
    Bcrypt.verify_pass(password, password_hash)
  end

  def checkpw(password, "$pbkdf2" <> _ = password_hash) do
    Pbkdf2.verify_pass(password, password_hash)
  end

  def checkpw(password, "$argon2" <> _ = password_hash) do
    Argon2.verify_pass(password, password_hash)
  end

  def checkpw(_password, _password_hash) do
    Logger.error("Password hash not recognized")
    false
  end

  @spec maybe_update_password(User.t(), String.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def maybe_update_password(%User{password_hash: "$2" <> _} = user, password) do
    do_update_password(user, password)
  end

  def maybe_update_password(%User{password_hash: "$6" <> _} = user, password) do
    do_update_password(user, password)
  end

  def maybe_update_password(%User{password_hash: "$pbkdf2" <> _} = user, password) do
    do_update_password(user, password)
  end

  def maybe_update_password(user, _), do: {:ok, user}

  defp do_update_password(user, password) do
    User.reset_password(user, %{password: password, password_confirmation: password})
  end
end
