defmodule Pleroma.Web.ActivityPub.MRF.DirectMessageDisabledPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.Web.ActivityPub.MRF.DirectMessageDisabledPolicy
  alias Pleroma.User

  describe "strips recipients" do
    test "when the user denies the direct message" do
      sender = insert(:user)
      recipient = insert(:user, %{accepts_direct_messages_from: :nobody})

      refute User.accepts_direct_messages?(recipient, sender)

      message = %{
        "actor" => sender.ap_id,
        "to" => [recipient.ap_id],
        "cc" => [],
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "to" => [recipient.ap_id]
        }
      }

      assert {:ok, %{"to" => [], "object" => %{"to" => []}}} =
               DirectMessageDisabledPolicy.filter(message)
    end

    test "when the user does not deny the direct message" do
      sender = insert(:user)
      recipient = insert(:user, %{accepts_direct_messages_from: :everybody})

      assert User.accepts_direct_messages?(recipient, sender)

      message = %{
        "actor" => sender.ap_id,
        "to" => [recipient.ap_id],
        "cc" => [],
        "type" => "Create",
        "object" => %{
          "type" => "Note",
          "to" => [recipient.ap_id]
        }
      }

      assert {:ok, message} = DirectMessageDisabledPolicy.filter(message)
      assert message["to"] == [recipient.ap_id]
      assert message["object"]["to"] == [recipient.ap_id]
    end
  end
end
