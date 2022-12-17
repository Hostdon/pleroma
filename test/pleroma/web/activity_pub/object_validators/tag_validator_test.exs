# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.TagValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.TagValidator

  test "it doesn't error on unusual objects" do
    edition = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Edition",
      "work" => "https://bookwyrm.com/book/9"
    }

    assert %{valid?: true, action: :ignore} = TagValidator.cast_and_validate(edition)
  end
end
