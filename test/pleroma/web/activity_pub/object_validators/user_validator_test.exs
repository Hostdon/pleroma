# Akkoma: Magically expressive social media
# Copyright © 2024 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UserValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.UserValidator

  # all standard actor types are listed here:
  # https://www.w3.org/TR/activitystreams-vocabulary/#actor-types
  describe "accepts standard type" do
    test "Application" do
      validates_file!("test/fixtures/mastodon/application_actor.json")
    end

    test "Group" do
      validates_file!("test/fixtures/peertube/actor-videochannel.json")
    end

    test "Organization" do
      validates_file!("test/fixtures/tesla_mock/wedistribute-user.json")
    end

    test "Person" do
      validates_file!("test/fixtures/bridgy/actor.json")
    end

    test "Service" do
      validates_file!("test/fixtures/mastodon/service_actor.json")
    end
  end

  defp validates_file!(path) do
    user_data = Jason.decode!(File.read!(path))
    {:ok, _validated_data, _meta} = UserValidator.validate(user_data, [])
  end
end
