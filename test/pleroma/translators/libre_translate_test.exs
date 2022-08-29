defmodule Pleroma.Akkoma.Translators.LibreTranslateTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Akkoma.Translators.LibreTranslate

  describe "translating with libre translate" do
    setup do
      clear_config([:libre_translate, :url], "http://libre.translate/translate")
    end

    test "should work without an API key" do
      Tesla.Mock.mock(fn
        %{method: :post, url: "http://libre.translate/translate"} = env ->
          assert {:ok, %{"api_key" => nil}} = Jason.decode(env.body)

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                detectedLanguage: %{
                  confidence: 83,
                  language: "ja"
                },
                translatedText: "I will crush you"
              })
          }
      end)

      assert {:ok, "ja", "I will crush you"} = LibreTranslate.translate("ギュギュ握りつぶしちゃうぞ", "en")
    end

    test "should work with an API key" do
      clear_config([:libre_translate, :api_key], "libre_translate_api_key")

      Tesla.Mock.mock(fn
        %{method: :post, url: "http://libre.translate/translate"} = env ->
          assert {:ok, %{"api_key" => "libre_translate_api_key"}} = Jason.decode(env.body)

          %Tesla.Env{
            status: 200,
            body:
              Jason.encode!(%{
                detectedLanguage: %{
                  confidence: 83,
                  language: "ja"
                },
                translatedText: "I will crush you"
              })
          }
      end)

      assert {:ok, "ja", "I will crush you"} = LibreTranslate.translate("ギュギュ握りつぶしちゃうぞ", "en")
    end

    test "should gracefully handle API key errors" do
      clear_config([:libre_translate, :api_key], "")

      Tesla.Mock.mock(fn
        %{method: :post, url: "http://libre.translate/translate"} ->
          %Tesla.Env{
            status: 403,
            body:
              Jason.encode!(%{
                error: "Please contact the server operator to obtain an API key"
              })
          }
      end)

      assert {:error, "libre_translate: request failed (code 403)"} =
               LibreTranslate.translate("ギュギュ握りつぶしちゃうぞ", "en")
    end

    test "should gracefully handle an unsupported language" do
      clear_config([:libre_translate, :api_key], "")

      Tesla.Mock.mock(fn
        %{method: :post, url: "http://libre.translate/translate"} ->
          %Tesla.Env{
            status: 400,
            body:
              Jason.encode!(%{
                error: "zoop is not supported"
              })
          }
      end)

      assert {:error, "libre_translate: request failed (code 400)"} =
               LibreTranslate.translate("ギュギュ握りつぶしちゃうぞ", "zoop")
    end
  end
end
