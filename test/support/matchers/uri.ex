defmodule Pleroma.Test.Matchers.URI do
  import ExUnit.Assertions

  def assert_uri_equals(%URI{} = uri_a, %URI{} = uri_b) do
    [:scheme, :authority, :userinfo, :host, :port, :path, :fragment]
    |> Enum.each(fn attribute ->
      if Map.get(uri_a, attribute) == Map.get(uri_b, attribute) do
        :ok
      else
        flunk("Expected #{uri_a} to match #{uri_b} - #{attribute} does not match")
      end
    end)

    # And the query string
    query_a = URI.decode_query(uri_a.query)
    query_b = URI.decode_query(uri_b.query)

    if query_a == query_b do
      :ok
    else
      flunk(
        "Expected #{uri_a} to match #{uri_b} - query parameters #{inspect(query_a)} do not match #{inspect(query_b)}"
      )
    end
  end

  def assert_uri_equals(uri_a, uri_b) when is_binary(uri_a) do
    uri_a
    |> URI.parse()
    |> assert_uri_equals(uri_b)
  end

  def assert_uri_equals(%URI{} = uri_a, uri_b) when is_binary(uri_b) do
    uri_b = URI.parse(uri_b)
    assert_uri_equals(uri_a, uri_b)
  end
end
