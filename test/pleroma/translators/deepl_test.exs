defmodule Pleroma.Akkoma.Translators.DeepLTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Akkoma.Translators.DeepL

  describe "translating with deepl" do
    setup do
      clear_config([:deepl, :api_key], "deepl_api_key")
    end

    test "should list supported languages" do
      clear_config([:deepl, :tier], :free)

      Tesla.Mock.mock(fn
        %{method: :get, url: "https://api-free.deepl.com/v2/languages?type=target"} = env ->
          auth_header = Enum.find(env.headers, fn {k, _v} -> k == "authorization" end)
          assert {"authorization", "DeepL-Auth-Key deepl_api_key"} = auth_header

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!([
                %{
                  "language" => "BG",
                  "name" => "Bulgarian",
                  "supports_formality" => false
                },
                %{
                  "language" => "CS",
                  "name" => "Czech",
                  "supports_formality" => false
                }
              ])
          }
      end)

      assert {:ok, [%{code: "BG", name: "Bulgarian"}, %{code: "CS", name: "Czech"}]} =
               DeepL.languages()
    end

    test "should work with the free tier" do
      clear_config([:deepl, :tier], :free)

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api-free.deepl.com/v2/translate"} = env ->
          auth_header = Enum.find(env.headers, fn {k, _v} -> k == "authorization" end)
          assert {"authorization", "DeepL-Auth-Key deepl_api_key"} = auth_header

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                translations: [
                  %{
                    "text" => "I will crush you",
                    "detected_source_language" => "ja"
                  }
                ]
              })
          }
      end)

      assert {:ok, "ja", "I will crush you"} = DeepL.translate("ギュギュ握りつぶしちゃうぞ", nil, "en")
    end

    test "should work with the pro tier" do
      clear_config([:deepl, :tier], :pro)

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.deepl.com/v2/translate"} = env ->
          auth_header = Enum.find(env.headers, fn {k, _v} -> k == "authorization" end)
          assert {"authorization", "DeepL-Auth-Key deepl_api_key"} = auth_header

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                translations: [
                  %{
                    "text" => "I will crush you",
                    "detected_source_language" => "ja"
                  }
                ]
              })
          }
      end)

      assert {:ok, "ja", "I will crush you"} = DeepL.translate("ギュギュ握りつぶしちゃうぞ", nil, "en")
    end

    test "should assign source language if set" do
      clear_config([:deepl, :tier], :pro)

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api.deepl.com/v2/translate"} = env ->
          auth_header = Enum.find(env.headers, fn {k, _v} -> k == "authorization" end)
          assert {"authorization", "DeepL-Auth-Key deepl_api_key"} = auth_header
          assert String.contains?(env.body, "source_lang=ja")

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                translations: [
                  %{
                    "text" => "I will crush you",
                    "detected_source_language" => "ja"
                  }
                ]
              })
          }
      end)

      assert {:ok, "ja", "I will crush you"} = DeepL.translate("ギュギュ握りつぶしちゃうぞ", "ja", "en")
    end

    test "should gracefully fail if the API errors" do
      clear_config([:deepl, :tier], :free)

      Tesla.Mock.mock(fn
        %{method: :post, url: "https://api-free.deepl.com/v2/translate"} ->
          %Tesla.Env{
            status: 403,
            body: ""
          }
      end)

      assert {:error, "DeepL request failed (code 403)"} =
               DeepL.translate("ギュギュ握りつぶしちゃうぞ", nil, "en")
    end
  end
end
