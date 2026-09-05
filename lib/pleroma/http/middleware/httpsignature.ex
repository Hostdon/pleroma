# Akkoma: Magically expressive social media
# Copyright © 2025 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Middleware.HTTPSignature do
  alias Pleroma.User.SigningKey
  alias Pleroma.Signature

  require Logger

  @behaviour Tesla.Middleware

  @moduledoc """
  Adds a HTTP signature and related headers to requests, if a signing key is set in the request env.
  If any other middleware can update the target location (e.g. redirects) this MUST be placed after all of them!

  (Note: the third argument holds static middleware options from client creation)
  """
  @impl true
  def call(env, next, _options) do
    env = maybe_sign(env)
    Tesla.run(env, next)
  end

  defp maybe_sign(env) do
    case Keyword.get(env.opts, :httpsig) do
      %{signing_key: %SigningKey{} = key} ->
        set_signature_headers(env, key)

      _ ->
        env
    end
  end

  defp set_signature_headers(env, key) do
    Logger.debug("Signing request to: #{env.url}")
    {http_headers, signing_headers} = collect_headers_for_signature(env)
    signature = Signature.sign(key, signing_headers, has_body: has_body(env))
    set_headers(env, [{"signature", signature} | http_headers])
  end

  defp has_body(%{body: body}) when body in [nil, ""], do: false
  defp has_body(_), do: true

  defp set_headers(env, []), do: env

  defp set_headers(env, [{key, val} | rest]) do
    headers = :proplists.delete(key, env.headers)
    headers = [{key, val} | headers]
    set_headers(%{env | headers: headers}, rest)
  end

  # Returns tuple.
  # First element is headers+values which need to be added to the HTTP request.
  # Second element are all headers to be used for signing, including already existing and pseudo headers.
  defp collect_headers_for_signature(env) do
    {request_target, host} = get_request_target_and_host(env)
    date = http_date()

    # content-length is always automatically set later on
    # since they are needed to establish working connection.
    # Similarly host will always be set for HTTP/1, and technically may be omitted for HTTP/2+
    # but Tesla doesn’t handle it well if we preset it ourselves (and seems to set it even for HTTP/2 anyway)
    http_headers = [{"date", date}]

    signing_headers = %{
      "(request-target)" => request_target,
      "host" => host,
      "date" => date
    }

    if has_body(env) do
      append_body_headers(env, http_headers, signing_headers)
    else
      {http_headers, signing_headers}
    end
  end

  defp append_body_headers(env, http_headers, signing_headers) do
    content_length = byte_size(env.body)
    digest = digest_value(env)

    http_headers = [{"digest", digest} | http_headers]

    signing_headers =
      Map.merge(signing_headers, %{
        "digest" => digest,
        "content-length" => content_length
      })

    {http_headers, signing_headers}
  end

  defp get_request_target_and_host(env) do
    uri = URI.parse(env.url)
    host = host_from_uri(uri)

    rt =
      if Pleroma.Config.get!([:activitypub, :sign_query_part]) do
        # correct behaviour as per cavage-12 RFC draft
        suffix = if uri.query, do: "?#{uri.query}", else: ""
        "#{env.method} #{uri.path}" <> suffix
      else
        # historically required for a long time by Mastodon
        "#{env.method} #{uri.path}"
      end

    {rt, host}
  end

  defp digest_value(env) do
    # case Tesla.get_header(env, "digest")
    encoded_hash = :crypto.hash(:sha256, env.body) |> Base.encode64()
    "SHA-256=" <> encoded_hash
  end

  defp host_from_uri(%URI{port: port, scheme: scheme, host: host}) do
    # https://httpwg.org/specs/rfc9110.html#field.host
    # https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.3
    if port == URI.default_port(scheme) do
      host
    else
      "#{host}:#{port}"
    end
  end

  defp http_date() do
    now = NaiveDateTime.utc_now()
    Timex.lformat!(now, "{WDshort}, {0D} {Mshort} {YYYY} {h24}:{m}:{s} GMT", "en")
  end
end
