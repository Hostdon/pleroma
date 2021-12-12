defmodule Pleroma.Search do
  @type search_map :: %{
          statuses: [map],
          accounts: [map],
          hashtags: [map]
        }

  @doc """
  Searches for stuff
  """
  @callback search(map, map, keyword) :: search_map
end
