defmodule Pleroma.Test.MatchingHelpers do
  import ExUnit.Assertions

  @assoc_fields [
    :signing_key
  ]
  def assert_user_match(actor1, actor2) do
    assert Ecto.reset_fields(actor1, @assoc_fields) == Ecto.reset_fields(actor2, @assoc_fields)
  end
end
