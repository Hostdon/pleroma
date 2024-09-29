defmodule Pleroma.HTTP.Backoff do
  alias Pleroma.HTTP
  require Logger

  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)
  @backoff_cache :http_backoff_cache

  # attempt to parse a timestamp from a header
  # returns nil if it can't parse the timestamp
  @spec timestamp_or_nil(binary) :: DateTime.t() | nil
  defp timestamp_or_nil(header) do
    case DateTime.from_iso8601(header) do
      {:ok, stamp, _} ->
        stamp

      _ ->
        nil
    end
  end

  # attempt to parse the x-ratelimit-reset header from the headers
  @spec x_ratelimit_reset(headers :: list) :: DateTime.t() | nil
  defp x_ratelimit_reset(headers) do
    with {_header, value} <- List.keyfind(headers, "x-ratelimit-reset", 0),
         true <- is_binary(value) do
      timestamp_or_nil(value)
    else
      _ ->
        nil
    end
  end

  # attempt to parse the Retry-After header from the headers
  # this can be either a timestamp _or_ a number of seconds to wait!
  # we'll return a datetime if we can parse it, or nil if we can't
  @spec retry_after(headers :: list) :: DateTime.t() | nil
  defp retry_after(headers) do
    with {_header, value} <- List.keyfind(headers, "retry-after", 0),
         true <- is_binary(value) do
      # first, see if it's an integer
      case Integer.parse(value) do
        {seconds, ""} ->
          Logger.debug("Parsed Retry-After header: #{seconds} seconds")
          DateTime.utc_now() |> Timex.shift(seconds: seconds)

        _ ->
          # if it's not an integer, try to parse it as a timestamp
          timestamp_or_nil(value)
      end
    else
      _ ->
        nil
    end
  end

  # given a set of headers, will attempt to find the next backoff timestamp
  # if it can't find one, it will default to 5 minutes from now
  @spec next_backoff_timestamp(%{headers: list}) :: DateTime.t()
  defp next_backoff_timestamp(%{headers: headers}) when is_list(headers) do
    default_5_minute_backoff =
      DateTime.utc_now()
      |> Timex.shift(seconds: 5 * 60)

    backoff =
      [&x_ratelimit_reset/1, &retry_after/1]
      |> Enum.map(& &1.(headers))
      |> Enum.find(&(&1 != nil))

    if is_nil(backoff) do
      Logger.debug("No backoff headers found, defaulting to 5 minutes from now")
      default_5_minute_backoff
    else
      Logger.debug("Found backoff header, will back off until: #{backoff}")
      backoff
    end
  end

  defp next_backoff_timestamp(_), do: DateTime.utc_now() |> Timex.shift(seconds: 5 * 60)

  # utility function to check the HTTP response for potential backoff headers
  # will check if we get a 429 or 503 response, and if we do, will back off for a bit
  @spec check_backoff({:ok | :error, HTTP.Env.t()}, binary()) ::
          {:ok | :error, HTTP.Env.t()} | {:error, :ratelimit}
  defp check_backoff({:ok, env}, host) do
    case env.status do
      status when status in [429, 503] ->
        Logger.error("Rate limited on #{host}! Backing off...")
        timestamp = next_backoff_timestamp(env)
        ttl = Timex.diff(timestamp, DateTime.utc_now(), :seconds)
        # we will cache the host for 5 minutes
        @cachex.put(@backoff_cache, host, true, ttl: ttl)
        {:error, :ratelimit}

      _ ->
        {:ok, env}
    end
  end

  defp check_backoff(env, _), do: env

  @doc """
  this acts as a single throughput for all GET requests
  we will check if the host is in the cache, and if it is, we will automatically fail the request
  this ensures that we don't hammer the server with requests, and instead wait for the backoff to expire
  this is a very simple implementation, and can be improved upon!
  """
  @spec get(binary, list, list) :: {:ok | :error, HTTP.Env.t()} | {:error, :ratelimit}
  def get(url, headers \\ [], options \\ []) do
    %{host: host} = URI.parse(url)

    case @cachex.get(@backoff_cache, host) do
      {:ok, nil} ->
        url
        |> HTTP.get(headers, options)
        |> check_backoff(host)

      _ ->
        {:error, :ratelimit}
    end
  end
end
