defmodule Pleroma.Akkoma.Translators.DeepL do
  @behaviour Pleroma.Akkoma.Translator

  alias Pleroma.HTTP
  alias Pleroma.Config
  require Logger

  defp base_url(:free) do
    "https://api-free.deepl.com/v2/"
  end

  defp base_url(:pro) do
    "https://api.deepl.com/v2/"
  end

  defp api_key do
    Config.get([:deepl, :api_key])
  end

  defp tier do
    Config.get([:deepl, :tier])
  end

  @impl Pleroma.Akkoma.Translator
  def translate(string, to_language) do
    with {:ok, %{status: 200} = response} <- do_request(api_key(), tier(), string, to_language),
         {:ok, body} <- Jason.decode(response.body) do
      %{"translations" => [%{"text" => translated, "detected_source_language" => detected}]} =
        body

      {:ok, detected, translated}
    else
      {:ok, %{status: status} = response} ->
        Logger.warning("DeepL: Request rejected: #{inspect(response)}")
        {:error, "DeepL request failed (code #{status})"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(api_key, tier, string, to_language) do
    HTTP.post(
      base_url(tier) <> "translate",
      URI.encode_query(
        %{
          text: string,
          target_lang: to_language
        },
        :rfc3986
      ),
      [
        {"authorization", "DeepL-Auth-Key #{api_key}"},
        {"content-type", "application/x-www-form-urlencoded"}
      ]
    )
  end
end
