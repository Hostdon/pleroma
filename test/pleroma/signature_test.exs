# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.SignatureTest do
  use Pleroma.DataCase, async: false
  @moduletag :mocked

  import Pleroma.Factory
  import Tesla.Mock

  alias HTTPSignatures.HTTPKey
  alias Pleroma.Signature
  alias Pleroma.User.SigningKey

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  @private_key "-----BEGIN RSA PRIVATE KEY-----\nMIIEpQIBAAKCAQEA48qb4v6kqigZutO9Ot0wkp27GIF2LiVaADgxQORZozZR63jH\nTaoOrS3Xhngbgc8SSOhfXET3omzeCLqaLNfXnZ8OXmuhJfJSU6mPUvmZ9QdT332j\nfN/g3iWGhYMf/M9ftCKh96nvFVO/tMruzS9xx7tkrfJjehdxh/3LlJMMImPtwcD7\nkFXwyt1qZTAU6Si4oQAJxRDQXHp1ttLl3Ob829VM7IKkrVmY8TD+JSlV0jtVJPj6\n1J19ytKTx/7UaucYvb9HIiBpkuiy5n/irDqKLVf5QEdZoNCdojOZlKJmTLqHhzKP\n3E9TxsUjhrf4/EqegNc/j982RvOxeu4i40zMQwIDAQABAoIBAQDH5DXjfh21i7b4\ncXJuw0cqget617CDUhemdakTDs9yH+rHPZd3mbGDWuT0hVVuFe4vuGpmJ8c+61X0\nRvugOlBlavxK8xvYlsqTzAmPgKUPljyNtEzQ+gz0I+3mH2jkin2rL3D+SksZZgKm\nfiYMPIQWB2WUF04gB46DDb2mRVuymGHyBOQjIx3WC0KW2mzfoFUFRlZEF+Nt8Ilw\nT+g/u0aZ1IWoszbsVFOEdghgZET0HEarum0B2Je/ozcPYtwmU10iBANGMKdLqaP/\nj954BPunrUf6gmlnLZKIKklJj0advx0NA+cL79+zeVB3zexRYSA5o9q0WPhiuTwR\n/aedWHnBAoGBAP0sDWBAM1Y4TRAf8ZI9PcztwLyHPzfEIqzbObJJnx1icUMt7BWi\n+/RMOnhrlPGE1kMhOqSxvXYN3u+eSmWTqai2sSH5Hdw2EqnrISSTnwNUPINX7fHH\njEkgmXQ6ixE48SuBZnb4w1EjdB/BA6/sjL+FNhggOc87tizLTkMXmMtTAoGBAOZV\n+wPuAMBDBXmbmxCuDIjoVmgSlgeRunB1SA8RCPAFAiUo3+/zEgzW2Oz8kgI+xVwM\n33XkLKrWG1Orhpp6Hm57MjIc5MG+zF4/YRDpE/KNG9qU1tiz0UD5hOpIU9pP4bR/\ngxgPxZzvbk4h5BfHWLpjlk8UUpgk6uxqfti48c1RAoGBALBOKDZ6HwYRCSGMjUcg\n3NPEUi84JD8qmFc2B7Tv7h2he2ykIz9iFAGpwCIyETQsJKX1Ewi0OlNnD3RhEEAy\nl7jFGQ+mkzPSeCbadmcpYlgIJmf1KN/x7fDTAepeBpCEzfZVE80QKbxsaybd3Dp8\nCfwpwWUFtBxr4c7J+gNhAGe/AoGAPn8ZyqkrPv9wXtyfqFjxQbx4pWhVmNwrkBPi\nZ2Qh3q4dNOPwTvTO8vjghvzIyR8rAZzkjOJKVFgftgYWUZfM5gE7T2mTkBYq8W+U\n8LetF+S9qAM2gDnaDx0kuUTCq7t87DKk6URuQ/SbI0wCzYjjRD99KxvChVGPBHKo\n1DjqMuECgYEAgJGNm7/lJCS2wk81whfy/ttKGsEIkyhPFYQmdGzSYC5aDc2gp1R3\nxtOkYEvdjfaLfDGEa4UX8CHHF+w3t9u8hBtcdhMH6GYb9iv6z0VBTt4A/11HUR49\n3Z7TQ18Iyh3jAUCzFV9IJlLIExq5Y7P4B3ojWFBN607sDCt8BMPbDYs=\n-----END RSA PRIVATE KEY-----"

  @public_key "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw0P/Tq4gb4G/QVuMGbJo\nC/AfMNcv+m7NfrlOwkVzcU47jgESuYI4UtJayissCdBycHUnfVUd9qol+eznSODz\nCJhfJloqEIC+aSnuEPGA0POtWad6DU0E6/Ho5zQn5WAWUwbRQqowbrsm/GHo2+3v\neR5jGenwA6sYhINg/c3QQbksyV0uJ20Umyx88w8+TJuv53twOfmyDWuYNoQ3y5cc\nHKOZcLHxYOhvwg3PFaGfFHMFiNmF40dTXt9K96r7sbzc44iLD+VphbMPJEjkMuf8\nPGEFOBzy8pm3wJZw2v32RNW2VESwMYyqDzwHXGSq1a73cS7hEnc79gXlELsK04L9\nQQIDAQAB\n-----END PUBLIC KEY-----\n"

  @rsa_public_key {
    :RSAPublicKey,
    24_650_000_183_914_698_290_885_268_529_673_621_967_457_234_469_123_179_408_466_269_598_577_505_928_170_923_974_132_111_403_341_217_239_999_189_084_572_368_839_502_170_501_850_920_051_662_384_964_248_315_257_926_552_945_648_828_895_432_624_227_029_881_278_113_244_073_644_360_744_504_606_177_648_469_825_063_267_913_017_309_199_785_535_546_734_904_379_798_564_556_494_962_268_682_532_371_146_333_972_821_570_577_277_375_020_977_087_539_994_500_097_107_935_618_711_808_260_846_821_077_839_605_098_669_707_417_692_791_905_543_116_911_754_774_323_678_879_466_618_738_207_538_013_885_607_095_203_516_030_057_611_111_308_904_599_045_146_148_350_745_339_208_006_497_478_057_622_336_882_506_112_530_056_970_653_403_292_123_624_453_213_574_011_183_684_739_084_105_206_483_178_943_532_208_537_215_396_831_110_268_758_639_826_369_857,
    # credo:disable-for-previous-line Credo.Check.Readability.MaxLineLength
    65_537
  }

  defp keyid(user = %Pleroma.User{}), do: keyid(user.ap_id)
  defp keyid(user_ap_id), do: user_ap_id <> "#main-key"

  defp assert_key(retval, refkey, refuser) do
    assert match?(
             {:ok, %HTTPKey{key: ^refkey, user_data: %{"key_user" => %Pleroma.User{}}}},
             retval
           )

    {:ok, key} = retval
    # Avoid comparison failures from (not) loaded Ecto associations etc
    assert refuser.id == key.user_data["key_user"].id
  end

  describe "fetch_public_key/1" do
    test "it returns the key" do
      user =
        insert(:user)
        |> with_signing_key(public_key: @public_key)

      assert_key(Signature.fetch_public_key(keyid(user), nil), @rsa_public_key, user)
    end

    test "it returns error if public key is nil" do
      # this actually needs the URL to be valid
      user = insert(:user)
      key_id = user.ap_id <> "#main-key"
      Tesla.Mock.mock(fn %{url: ^key_id} -> {:ok, %{status: 404}} end)

      assert {:error, _} = Signature.fetch_public_key(keyid(user), nil)
    end
  end

  describe "refetch_public_key/1" do
    test "it returns key" do
      clear_config([:activitypub, :min_key_refetch_interval], 0)
      ap_id = "https://mastodon.social/users/lambadalambda"

      %Pleroma.User{signing_key: sk} =
        user =
        Pleroma.User.get_or_fetch_by_ap_id(ap_id)
        |> then(fn {:ok, u} -> u end)
        |> SigningKey.load_key()

      {:ok, _} =
        %{sk | public_key: "-----BEGIN PUBLIC KEY-----\nasdfghjkl"}
        |> Ecto.Changeset.change()
        |> Pleroma.Repo.update()

      assert_key(Signature.refetch_public_key(keyid(ap_id), nil), @rsa_public_key, user)
    end
  end

  defp split_signature(sig) do
    sig
    |> String.split(",")
    |> Enum.map(fn part ->
      [key, value] = String.split(part, "=", parts: 2)
      [key, String.trim(value, ~s|"|)]
    end)
    |> Enum.sort_by(fn [k, _] -> k end)
  end

  # Break up a signature and check by parts
  defp assert_signature_equal(sig_a, sig_b) when is_binary(sig_a) and is_binary(sig_b) do
    parts_a = split_signature(sig_a)
    parts_b = split_signature(sig_b)

    parts_a
    |> Enum.with_index()
    |> Enum.each(fn {part_a, index} ->
      part_b = Enum.at(parts_b, index)
      assert_part_equal(part_a, part_b)
    end)
  end

  defp assert_part_equal(part_a, part_b) do
    if part_a != part_b do
      flunk("Signature check failed - expected #{part_a} to equal #{part_b}")
    end
  end

  describe "sign/2" do
    test "it returns signature headers" do
      user =
        insert(:user, %{
          ap_id: "https://mastodon.social/users/lambadalambda"
        })
        |> with_signing_key(private_key: @private_key)

      headers = %{
        "host" => "test.test",
        "content-length" => "100",
        "date" => "Fri, 23 Aug 2019 18:11:24 GMT",
        "digest" => "SHA-256=a29cdd711788c5118a2256c00d31519e0a5a0d4b144214e012f81e67b80b0ec1",
        "(request-target)" => "post https://example.com/inbox"
      }

      assert_signature_equal(
        Signature.sign(
          user.signing_key,
          headers
        ),
        ~s|keyId="https://mastodon.social/users/lambadalambda#main-key",algorithm="rsa-sha256",headers="(request-target) content-length date digest host",signature="fhOT6IBThnCo6rv2Tv8BRXLV7LvVf/7wTX/bbPLtdq5A4GUqrmXUcY5p77jQ6NU9IRIVczeeStxQV6TrHqk/qPdqQOzDcB6cWsSfrB1gsTinBbAWdPzQYqUOTl+Minqn2RERAfPebKYr9QGa0sTODDHvze/UFPuL8a1lDO2VQE0lRCdg49Igr8pGl/CupUx8Fb874omqP0ba3M+siuKEwo02m9hHcbZUeLSN0ZVdvyTMttyqPM1BfwnFXkaQRAblLTyzt4Fv2+fTN+zPipSxJl1YIo1TsmwNq9klqImpjh8NHM3MJ5eZxTZ109S6Q910n1Lm46V/SqByDaYeg9g7Jw=="|
      )
    end
  end
end
