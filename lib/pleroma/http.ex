# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP do
  @moduledoc """
    Wrapper for `Tesla.request/2`.
  """

  alias Tesla.Env

  require Logger

  @type t :: __MODULE__
  @type method() :: :get | :post | :put | :delete | :head

  @mix_env Mix.env()

  @doc """
  Performs GET request.

  See `Pleroma.HTTP.request/5`
  """
  @spec get(Request.url() | nil, Request.headers(), keyword()) ::
          nil | {:ok, Env.t()} | {:error, any()}
  def get(url, headers \\ [], options \\ [])
  def get(nil, _, _), do: nil
  def get(url, headers, options), do: request(:get, url, nil, headers, options)

  @spec head(Request.url(), Request.headers(), keyword()) :: {:ok, Env.t()} | {:error, any()}
  def head(url, headers \\ [], options \\ []), do: request(:head, url, nil, headers, options)

  @doc """
  Performs POST request.

  See `Pleroma.HTTP.request/5`
  """
  @spec post(Request.url(), String.t(), Request.headers(), keyword()) ::
          {:ok, Env.t()} | {:error, any()}
  def post(url, body, headers \\ [], options \\ []),
    do: request(:post, url, body, headers, options)

  @doc """
  Builds and performs http request.

  # Arguments:
  `method` - :get, :post, :put, :delete, :head
  `url` - full url
  `body` - request body
  `headers` - a keyworld list of headers, e.g. `[{"content-type", "text/plain"}]`
  `options` - custom, per-request middleware or adapter options

  # Returns:
  `{:ok, %Tesla.Env{}}` or `{:error, error}`

  """
  @spec request(method(), Request.url(), String.t(), Request.headers(), keyword()) ::
          {:ok, Env.t()} | {:error, any()}
  def request(method, url, body, headers, options) when is_binary(url) do
    params = options[:params] || []
    options = options |> Keyword.delete(:params)
    headers = maybe_add_user_agent(headers)

    client = build_client(method)

    Logger.debug("Outbound: #{method} #{url}")

    Tesla.request(client,
      method: method,
      url: url,
      query: params,
      headers: headers,
      body: body,
      opts: options
    )
  rescue
    e ->
      Logger.error("Failed to fetch #{url}: #{Exception.format(:error, e, __STACKTRACE__)}")
      {:error, :fetch_error}
  end

  defp build_client(method) do
    # Orders of middlewares matters!
    # We start construction with the middlewares _last_ to run
    # on outgoing requests (and first on incoming responses).
    # This allows using more efficient list prepending.
    middlewares = [Tesla.Middleware.Telemetry]

    # XXX: just like the user-agent header below, our current mocks can't handle extra headers
    #      and would break if we used the decompression middleware during tests.
    #      The :test condition can and should be removed once mocks are fixed.
    #
    # HEAD responses won't contain a body to compress anyway and we sometimes use
    # HEAD requests to determine whether a remote resource is within size limits before fetching it.
    # If the server would send a compressed response however, Content-Length will be the size of
    # the _compressed_ response body skewing results.
    middlewares =
      if method != :head and @mix_env != :test do
        [{Tesla.Middleware.DecompressResponse, max_body_size: 512_000_000} | middlewares]
      else
        middlewares
      end

    middlewares = [
      Tesla.Middleware.FollowRedirects,
      Pleroma.HTTP.Middleware.HTTPSignature | middlewares
    ]

    Tesla.client(middlewares)
  end

  # XXX: our test mocks are (too) strict about headers and cannot handle user-agent atm
  if @mix_env == :test do
    defp maybe_add_user_agent(headers) do
      with true <- Pleroma.Config.get([:http, :send_user_agent]) do
        [{"user-agent", Pleroma.Application.user_agent()} | headers]
      else
        _ ->
          headers
      end
    end
  else
    defp maybe_add_user_agent(headers),
      do: [{"user-agent", Pleroma.Application.user_agent()} | headers]
  end
end
