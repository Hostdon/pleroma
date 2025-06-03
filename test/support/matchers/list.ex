defmodule Pleroma.Test.Matchers.List do
  import ExUnit.Assertions

  def assert_unordered_list_equal(list_a, list_b) when is_list(list_a) and is_list(list_b) do
    list_a = Enum.sort(list_a)
    list_b = Enum.sort(list_b)

    if list_a != list_b do
      flunk("Expected list
      #{inspect(list_a)}
      to have the same elements as 
      #{inspect(list_b)}
      ")
    end
  end
end
