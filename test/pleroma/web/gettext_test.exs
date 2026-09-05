# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.GettextTest do
  use ExUnit.Case

  use Gettext, backend: Pleroma.Web.Gettext
  require Pleroma.Web.GettextCompanion

  describe "handle_missing_translation/5" do
    test "fallback to next locale if some translation is not available" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported", "en_test"] do
        assert "xxYour account is awaiting approvalxx" ==
                 dpgettext(
                   "static_pages",
                   "approval pending email subject",
                   "Your account is awaiting approval"
                 )
      end
    end

    test "putting en locale at the front should not make gettext fallback unexpectedly" do
      Pleroma.Web.GettextCompanion.with_locales ["en", "en_test"] do
        assert "Your account is awaiting approval" ==
                 dpgettext(
                   "static_pages",
                   "approval pending email subject",
                   "Your account is awaiting approval"
                 )
      end
    end

    test "duplicated locale in list should not result in infinite loops" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported", "x_unsupported", "en_test"] do
        assert "xxYour account is awaiting approvalxx" ==
                 dpgettext(
                   "static_pages",
                   "approval pending email subject",
                   "Your account is awaiting approval"
                 )
      end
    end

    test "direct interpolation" do
      Pleroma.Web.GettextCompanion.with_locales ["en_test"] do
        assert "xxYour digest from some instancexx" ==
                 dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end

    test "fallback with interpolation" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported", "en_test"] do
        assert "xxYour digest from some instancexx" ==
                 dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end

    test "fallback to msgid" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported"] do
        assert "Your digest from some instance" ==
                 dpgettext(
                   "static_pages",
                   "digest email subject",
                   "Your digest from %{instance_name}",
                   instance_name: "some instance"
                 )
      end
    end
  end

  describe "handle_missing_plural_translation/7" do
    test "direct interpolation" do
      Pleroma.Web.GettextCompanion.with_locales ["en_test"] do
        assert "xx1 New Followerxx" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "xx5 New Followersxx" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end

    test "fallback with interpolation" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported", "en_test"] do
        assert "xx1 New Followerxx" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "xx5 New Followersxx" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end

    test "fallback to msgid" do
      Pleroma.Web.GettextCompanion.with_locales ["x_unsupported"] do
        assert "1 New Follower" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   1,
                   count: 1
                 )

        assert "5 New Followers" ==
                 dpngettext(
                   "static_pages",
                   "new followers count header",
                   "%{count} New Follower",
                   "%{count} New Followers",
                   5,
                   count: 5
                 )
      end
    end
  end
end
