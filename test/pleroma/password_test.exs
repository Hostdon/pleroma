defmodule Pleroma.PasswordTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  import ExUnit.CaptureLog

  alias Pleroma.Password

  describe "hash_pwd_salt/1" do
    test "returns a hash" do
      assert "$argon2id" <> _ = Password.hash_pwd_salt("test")
    end
  end

  describe "maybe_update_password/2" do
    test "with a bcrypt hash, it updates to an argon2 hash" do
      user = insert(:user, password_hash: Bcrypt.hash_pwd_salt("123"))
      assert "$2" <> _ = user.password_hash

      {:ok, user} = Password.maybe_update_password(user, "123")
      assert "$argon2" <> _ = user.password_hash
    end

    test "with a pbkdf2 hash, it updates to an argon2 hash" do
      user = insert(:user, password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("123"))
      assert "$pbkdf2" <> _ = user.password_hash

      {:ok, user} = Password.maybe_update_password(user, "123")
      assert "$argon2" <> _ = user.password_hash
    end
  end

  describe "checkpw/2" do
    test "check pbkdf2 hash" do
      hash =
        "$pbkdf2-sha512$160000$loXqbp8GYls43F0i6lEfIw$AY.Ep.2pGe57j2hAPY635sI/6w7l9Q9u9Bp02PkPmF3OrClDtJAI8bCiivPr53OKMF7ph6iHhN68Rom5nEfC2A"

      assert Password.checkpw("test-password", hash)
      refute Password.checkpw("test-password1", hash)
    end

    test "check bcrypt hash" do
      hash = "$2a$10$uyhC/R/zoE1ndwwCtMusK.TLVzkQ/Ugsbqp3uXI.CTTz0gBw.24jS"

      assert Password.checkpw("password", hash)
      refute Password.checkpw("password1", hash)
    end

    test "check argon2 hash" do
      hash =
        "$argon2id$v=19$m=65536,t=8,p=2$zEMMsTuK5KkL5AFWbX7jyQ$VyaQD7PF6e9btz0oH1YiAkWwIGZ7WNDZP8l+a/O171g"

      assert Password.checkpw("password", hash)
      refute Password.checkpw("password1", hash)
    end

    test "it returns false when hash invalid" do
      hash =
        "psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"

      assert capture_log(fn ->
               refute Password.checkpw("password", hash)
             end) =~ "[error] Password hash not recognized"
    end
  end
end
