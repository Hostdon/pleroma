defmodule Pleroma.HTTP.BackoffTest do
  @backoff_cache :http_backoff_cache
  use Pleroma.DataCase, async: false
  alias Pleroma.HTTP.Backoff

  defp within_tolerance?(ttl, expected) do
    ttl > expected - 10 and ttl < expected + 10
  end

  describe "get/3" do
    test "should return {:ok, env} when not rate limited" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://akkoma.dev/api/v1/instance"} ->
          {:ok, %Tesla.Env{status: 200, body: "ok"}}
      end)

      assert {:ok, env} = Backoff.get("https://akkoma.dev/api/v1/instance")
      assert env.status == 200
    end

    test "should return {:error, env} when rate limited" do
      # Shove a value into the cache to simulate a rate limit
      Cachex.put(@backoff_cache, "akkoma.dev", true)
      assert {:error, :ratelimit} = Backoff.get("https://akkoma.dev/api/v1/instance")
    end

    test "should insert a value into the cache when rate limited" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://ratelimited.dev/api/v1/instance"} ->
          {:ok, %Tesla.Env{status: 429, body: "Rate limited"}}
      end)

      assert {:error, :ratelimit} = Backoff.get("https://ratelimited.dev/api/v1/instance")
      assert {:ok, true} = Cachex.get(@backoff_cache, "ratelimited.dev")
    end

    test "should insert a value into the cache when rate limited with a 503 response" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://ratelimited.dev/api/v1/instance"} ->
          {:ok, %Tesla.Env{status: 503, body: "Rate limited"}}
      end)

      assert {:error, :ratelimit} = Backoff.get("https://ratelimited.dev/api/v1/instance")
      assert {:ok, true} = Cachex.get(@backoff_cache, "ratelimited.dev")
    end

    test "should parse the value of x-ratelimit-reset, if present" do
      ten_minutes_from_now =
        DateTime.utc_now() |> Timex.shift(minutes: 10) |> DateTime.to_iso8601()

      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://ratelimited.dev/api/v1/instance"} ->
          {:ok,
           %Tesla.Env{
             status: 429,
             body: "Rate limited",
             headers: [{"x-ratelimit-reset", ten_minutes_from_now}]
           }}
      end)

      assert {:error, :ratelimit} = Backoff.get("https://ratelimited.dev/api/v1/instance")
      assert {:ok, true} = Cachex.get(@backoff_cache, "ratelimited.dev")
      {:ok, ttl} = Cachex.ttl(@backoff_cache, "ratelimited.dev")
      assert within_tolerance?(ttl, 600)
    end

    test "should parse the value of retry-after when it's a timestamp" do
      ten_minutes_from_now =
        DateTime.utc_now() |> Timex.shift(minutes: 10) |> DateTime.to_iso8601()

      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://ratelimited.dev/api/v1/instance"} ->
          {:ok,
           %Tesla.Env{
             status: 429,
             body: "Rate limited",
             headers: [{"retry-after", ten_minutes_from_now}]
           }}
      end)

      assert {:error, :ratelimit} = Backoff.get("https://ratelimited.dev/api/v1/instance")
      assert {:ok, true} = Cachex.get(@backoff_cache, "ratelimited.dev")
      {:ok, ttl} = Cachex.ttl(@backoff_cache, "ratelimited.dev")
      assert within_tolerance?(ttl, 600)
    end

    test "should parse the value of retry-after when it's a number of seconds" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{url: "https://ratelimited.dev/api/v1/instance"} ->
          {:ok,
           %Tesla.Env{
             status: 429,
             body: "Rate limited",
             headers: [{"retry-after", "600"}]
           }}
      end)

      assert {:error, :ratelimit} = Backoff.get("https://ratelimited.dev/api/v1/instance")
      assert {:ok, true} = Cachex.get(@backoff_cache, "ratelimited.dev")
      # assert that the value is 10 minutes from now
      {:ok, ttl} = Cachex.ttl(@backoff_cache, "ratelimited.dev")
      assert within_tolerance?(ttl, 600)
    end
  end
end
