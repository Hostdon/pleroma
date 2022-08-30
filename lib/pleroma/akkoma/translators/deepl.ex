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
  def languages do
    with {:ok, %{status: 200} = source_response} <- do_languages("source"),
         {:ok, %{status: 200} = dest_response} <- do_languages("target"),
         {:ok, source_body} <- Jason.decode(source_response.body),
         {:ok, dest_body} <- Jason.decode(dest_response.body) do
      source_resp =
        Enum.map(source_body, fn %{"language" => code, "name" => name} ->
          %{code: code, name: name}
        end)

      dest_resp =
        Enum.map(dest_body, fn %{"language" => code, "name" => name} ->
          %{code: code, name: name}
        end)

      {:ok, source_resp, dest_resp}
    else
      {:ok, %{status: status} = response} ->
        Logger.warning("DeepL: Request rejected: #{inspect(response)}")
        {:error, "DeepL request failed (code #{status})"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Pleroma.Akkoma.Translator
  def translate(string, from_language, to_language) do
    with {:ok, %{status: 200} = response} <-
           do_request(api_key(), tier(), string, from_language, to_language),
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

  defp do_request(api_key, tier, string, from_language, to_language) do
    HTTP.post(
      base_url(tier) <> "translate",
      URI.encode_query(
        %{
          text: string,
          target_lang: to_language,
          tag_handling: "html"
        }
        |> maybe_add_source(from_language),
        :rfc3986
      ),
      [
        {"authorization", "DeepL-Auth-Key #{api_key}"},
        {"content-type", "application/x-www-form-urlencoded"}
      ]
    )
  end

  defp maybe_add_source(opts, nil), do: opts
  defp maybe_add_source(opts, lang), do: Map.put(opts, :source_lang, lang)

  defp do_languages(type) do
    HTTP.get(
      base_url(tier()) <> "languages?type=#{type}",
      [
        {"authorization", "DeepL-Auth-Key #{api_key()}"}
      ]
    )
  end
end
