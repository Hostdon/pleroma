defmodule Pleroma.ISO639 do
  @file "priv/language-codes.json"
  @data File.read!(@file)
        |> Jason.decode!()

  for %{"alpha2" => alpha2} <- @data do
    def valid_alpha2?(unquote(alpha2)), do: true
  end

  def valid_alpha2?(_alpha2), do: false
end
