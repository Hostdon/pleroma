# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.SigningKeyTests do
  alias Pleroma.User
  alias Pleroma.User.SigningKey
  alias Pleroma.Repo

  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  defp maybe_put(map, _, nil), do: map
  defp maybe_put(map, key, val), do: Kernel.put_in(map, key, val)

  defp get_body_actor(key_id \\ nil, user_id \\ nil, owner_id \\ nil) do
    owner_id = owner_id || user_id

    File.read!("test/fixtures/tesla_mock/admin@mastdon.example.org.json")
    |> Jason.decode!()
    |> maybe_put(["id"], user_id)
    |> maybe_put(["publicKey", "id"], key_id)
    |> maybe_put(["publicKey", "owner"], owner_id)
    |> Jason.encode!()
  end

  defp get_body_rawkey(key_id, owner, pem \\ "RSA begin buplic key") do
    %{
      "type" => "CryptographicKey",
      "id" => key_id,
      "owner" => owner,
      "publicKeyPem" => pem
    }
    |> Jason.encode!()
  end

  defmacro mock_tesla(
             url,
             get_body,
             status \\ 200,
             headers \\ []
           ) do
    quote do
      Tesla.Mock.mock(fn
        %{method: :get, url: unquote(url)} ->
          %Tesla.Env{
            status: unquote(status),
            body: unquote(get_body),
            url: unquote(url),
            headers: [
              {"content-type",
               "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""}
              | unquote(headers)
            ]
          }
      end)
    end
  end

  describe "succesfully" do
    test "inserts key and new user on fetch" do
      ap_id_actor = "https://mastodon.example.org/signing-key-test/actor"
      ap_id_key = ap_id_actor <> "#main-key"
      ap_doc = get_body_actor(ap_id_key, ap_id_actor)
      mock_tesla(ap_id_actor, ap_doc)

      {:ok, %SigningKey{} = key} = SigningKey.fetch_remote_key(ap_id_key)
      user = User.get_by_id(key.user_id)

      assert match?(%User{}, user)
      user = SigningKey.load_key(user)

      assert user.ap_id == ap_id_actor
      assert user.signing_key.key_id == ap_id_key
      assert user.signing_key.key_id == key.key_id
      assert user.signing_key.private_key == nil
    end

    test "updates existing key" do
      user =
        insert(:user, local: false, domain: "mastodon.example.org")
        |> with_signing_key()

      ap_id_actor = user.ap_id
      ap_doc = get_body_actor(user.signing_key.key_id, ap_id_actor)
      mock_tesla(ap_id_actor, ap_doc)

      old_pem = user.signing_key.public_key
      old_priv = user.signing_key.private_key

      # note: the returned value does not fully match the value stored in the database
      # since inserted_at isn't changed on upserts
      {:ok, %SigningKey{} = key} = SigningKey.fetch_remote_key(user.signing_key.key_id)

      refreshed_key = Repo.get_by(SigningKey, key_id: key.key_id)
      assert match?(%SigningKey{}, refreshed_key)
      refute refreshed_key.public_key == old_pem
      assert refreshed_key.private_key == old_priv
      assert refreshed_key.user_id == user.id
      assert key.public_key == refreshed_key.public_key
    end

    test "finds known key by key_id" do
      sk = insert(:signing_key, key_id: "https://remote.example/signing-key-test/some-kown-key")
      {:ok, key} = SigningKey.get_or_fetch_by_key_id(sk.key_id)
      assert sk == key
    end

    test "finds key for remote user" do
      user_with_preload =
        insert(:user, local: false)
        |> with_signing_key()

      user = User.get_by_id(user_with_preload.id)
      assert !match?(%SigningKey{}, user.signing_key)

      user = SigningKey.load_key(user)
      assert match?(%SigningKey{}, user.signing_key)

      # the initial "with_signing_key" doesn't set timestamps, and meta differs (loaded vs built)
      # thus clear affected fields before comparison
      found_sk = %{user.signing_key | inserted_at: nil, updated_at: nil, __meta__: nil}
      ref_sk = %{user_with_preload.signing_key | __meta__: nil}
      assert found_sk == ref_sk
    end

    test "finds remote user id by key id" do
      user =
        insert(:user, local: false)
        |> with_signing_key()

      uid = SigningKey.key_id_to_user_id(user.signing_key.key_id)
      assert uid == user.id
    end

    test "finds remote user ap id by key id" do
      user =
        insert(:user, local: false)
        |> with_signing_key()

      uapid = SigningKey.key_id_to_ap_id(user.signing_key.key_id)
      assert uapid == user.ap_id
    end
  end

  test "won't fetch keys for local users" do
    user =
      insert(:user, local: true)
      |> with_signing_key()

    {:error, _} = SigningKey.fetch_remote_key(user.signing_key.key_id)
  end

  test "fails insert with overlapping key owner" do
    user =
      insert(:user, local: false)
      |> with_signing_key()

    second_key_id =
      user.signing_key.key_id
      |> URI.parse()
      |> Map.put(:fragment, nil)
      |> Map.put(:query, nil)
      |> URI.to_string()
      |> then(fn id -> id <> "/second_key" end)

    ap_doc = get_body_rawkey(second_key_id, user.ap_id)
    mock_tesla(second_key_id, ap_doc)

    res = SigningKey.fetch_remote_key(second_key_id)

    assert match?({:error, %{errors: _}}, res)
    {:error, cs} = res
    assert Keyword.has_key?(cs.errors, :user_id)
  end

  test "Fetched raw SigningKeys cannot take over arbitrary users" do
    # in theory cross-domain key and actor are fine, IF and ONLY IF
    # the actor also links back to this key, but this isn’t supported atm anyway
    user =
      insert(:user, local: false)
      |> with_signing_key()

    remote_key_id = "https://remote.example/keys/for_local"
    keydoc = get_body_rawkey(remote_key_id, user.ap_id)
    mock_tesla(remote_key_id, keydoc)

    {:error, _} = SigningKey.fetch_remote_key(remote_key_id)

    refreshed_org_key = Repo.get_by(SigningKey, key_id: user.signing_key.key_id)
    refreshed_user_key = Repo.get_by(SigningKey, user_id: user.id)
    assert match?(%SigningKey{}, refreshed_org_key)
    assert match?(%SigningKey{}, refreshed_user_key)

    actor_host = URI.parse(user.ap_id).host
    org_key_host = URI.parse(refreshed_org_key.key_id).host
    usr_key_host = URI.parse(refreshed_user_key.key_id).host
    assert actor_host == org_key_host
    assert actor_host == usr_key_host
    refute usr_key_host == "remote.example"

    assert refreshed_user_key == refreshed_org_key
    assert user.signing_key.key_id == refreshed_org_key.key_id
  end

  test "Fetched non-raw SigningKey cannot take over arbitrary users" do
    # this actually comes free with our fetch ID checks, but lets verify it here too for good measure
    user =
      insert(:user, local: false)
      |> with_signing_key()

    remote_key_id = "https://remote.example/keys#for_local"
    keydoc = get_body_actor(remote_key_id, user.ap_id, user.ap_id)
    mock_tesla(remote_key_id, keydoc)

    {:error, _} = SigningKey.fetch_remote_key(remote_key_id)

    refreshed_org_key = Repo.get_by(SigningKey, key_id: user.signing_key.key_id)
    refreshed_user_key = Repo.get_by(SigningKey, user_id: user.id)
    assert match?(%SigningKey{}, refreshed_org_key)
    assert match?(%SigningKey{}, refreshed_user_key)

    actor_host = URI.parse(user.ap_id).host
    org_key_host = URI.parse(refreshed_org_key.key_id).host
    usr_key_host = URI.parse(refreshed_user_key.key_id).host
    assert actor_host == org_key_host
    assert actor_host == usr_key_host
    refute usr_key_host == "remote.example"

    assert refreshed_user_key == refreshed_org_key
    assert user.signing_key.key_id == refreshed_org_key.key_id
  end

  test "remote users sharing signing key ID don't break our database" do
    # in principle a valid setup using this can be cosntructed,
    # but so far not observed in practice and our db scheme cannot handle it.
    # Thus make sure it doesn't break our db anything but gets rejected
    key_id = "https://mastodon.example.org/the_one_key"

    user1 =
      insert(:user, local: false, domain: "mastodon.example.org")
      |> with_signing_key(%{key_id: key_id})

    key_owner = "https://mastodon.example.org/#"

    user2_ap_id = user1.ap_id <> "22"
    user2_doc = get_body_actor(user1.signing_key.key_id, user2_ap_id, key_owner)

    user3_ap_id = user1.ap_id <> "333"
    user3_doc = get_body_actor(user1.signing_key.key_id, user2_ap_id)

    standalone_key_doc =
      get_body_rawkey(key_id, "https://mastodon.example.org/#", user1.signing_key.public_key)

    ap_headers = [
      {"content-type", "application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""}
    ]

    Tesla.Mock.mock(fn
      %{method: :get, url: ^key_id} ->
        %Tesla.Env{
          status: 200,
          body: standalone_key_doc,
          url: key_id,
          headers: ap_headers
        }

      %{method: :get, url: ^user2_ap_id} ->
        %Tesla.Env{
          status: 200,
          body: user2_doc,
          url: user2_ap_id,
          headers: ap_headers
        }

      %{method: :get, url: ^user3_ap_id} ->
        %Tesla.Env{
          status: 200,
          body: user3_doc,
          url: user3_ap_id,
          headers: ap_headers
        }
    end)

    {:error, _} = SigningKey.fetch_remote_key(key_id)

    {:ok, user2} = User.get_or_fetch_by_ap_id(user2_ap_id)
    {:ok, user3} = User.get_or_fetch_by_ap_id(user3_ap_id)

    {:ok, db_key} = SigningKey.get_or_fetch_by_key_id(key_id)

    keys =
      from(s in SigningKey, where: s.key_id == ^key_id)
      |> Repo.all()

    assert match?([%SigningKey{}], keys)
    assert [db_key] == keys
    assert db_key.user_id == user1.id
    assert match?({:ok, _}, SigningKey.public_key(user1))
    assert {:error, "key not found"} == SigningKey.public_key(user2)
    assert {:error, "key not found"} == SigningKey.public_key(user3)
  end
end
