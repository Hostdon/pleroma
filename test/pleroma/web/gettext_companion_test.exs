# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.GettextCompanionTest do
  use ExUnit.Case

  require Pleroma.Web.GettextCompanion

  test "put_locales/1: set the first in the list to Gettext's locale" do
    Pleroma.Web.GettextCompanion.put_locales(["zh_Hans", "en_test"])

    assert "zh_Hans" == Gettext.get_locale(Pleroma.Web.Gettext)
  end

  test "with_locales/2: reset locale on exit" do
    old_first_locale = Gettext.get_locale(Pleroma.Web.Gettext)
    old_locales = Pleroma.Web.GettextCompanion.get_locales()

    Pleroma.Web.GettextCompanion.with_locales ["zh_Hans", "en_test"] do
      assert "zh_Hans" == Gettext.get_locale(Pleroma.Web.Gettext)
      assert ["zh_Hans", "en_test"] == Pleroma.Web.GettextCompanion.get_locales()
    end

    assert old_first_locale == Gettext.get_locale(Pleroma.Web.Gettext)
    assert old_locales == Pleroma.Web.GettextCompanion.get_locales()
  end
end
