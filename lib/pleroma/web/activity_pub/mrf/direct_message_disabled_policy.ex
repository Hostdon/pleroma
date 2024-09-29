defmodule Pleroma.Web.ActivityPub.MRF.DirectMessageDisabledPolicy do
  @behaviour Pleroma.Web.ActivityPub.MRF.Policy

  alias Pleroma.User
  require Pleroma.Constants

  @moduledoc """
  Removes entries from the "To" field from direct messages if the user has requested to not
  allow direct messages
  """

  @impl true
  def filter(
        %{
          "type" => "Create",
          "actor" => actor,
          "object" => %{
            "type" => "Note"
          }
        } = activity
      ) do
    with recipients <- Map.get(activity, "to", []),
         cc <- Map.get(activity, "cc", []),
         true <- is_direct?(recipients, cc),
         sender <- User.get_cached_by_ap_id(actor) do
      new_to =
        Enum.filter(recipients, fn recv ->
          should_include?(sender, recv)
        end)

      {:ok,
       activity
       |> Map.put("to", new_to)
       |> maybe_replace_object_to(new_to)}
    else
      _ ->
        {:ok, activity}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe, do: {:ok, %{}}

  defp should_include?(sender, receiver_ap_id) do
    with %User{local: true} = receiver <- User.get_cached_by_ap_id(receiver_ap_id) do
      User.accepts_direct_messages?(receiver, sender)
    else
      _ -> true
    end
  end

  defp maybe_replace_object_to(%{"object" => %{"to" => _}} = activity, to) do
    Kernel.put_in(activity, ["object", "to"], to)
  end

  defp maybe_replace_object_to(other, _), do: other

  defp is_direct?(to, cc) do
    !(Enum.member?(to, Pleroma.Constants.as_public()) ||
        Enum.member?(cc, Pleroma.Constants.as_public()))
  end
end
