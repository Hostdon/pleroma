# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Gettext do
  @moduledoc """
  A module providing Internationalization with a gettext-based API.

  By using [Gettext](https://hexdocs.pm/gettext),
  your module gains a set of macros for translations, for example:

      use Gettext, backend: Pleroma.Web.Gettext

      # Simple translation
      gettext "Here is the string to translate"

      # Plural translation
      ngettext "Here is the string to translate",
               "Here are the strings to translate",
               3

      # Domain-based translation
      dgettext "errors", "Here is the error message to translate"

  See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
  """
  use Gettext.Backend, otp_app: :pleroma

  defp next_locale(locale, list) do
    index = Enum.find_index(list, fn item -> item == locale end)

    if not is_nil(index) do
      Enum.at(list, index + 1)
    else
      nil
    end
  end

  # We do not yet have a proper English translation. The "English"
  # version is currently but the fallback msgid. However, this
  # will not work if the user puts English as the first language,
  # and at the same time specifies other languages, as gettext will
  # think the English translation is missing, and call
  # handle_missing_translation functions. This may result in
  # text in other languages being shown even if English is preferred
  # by the user.
  #
  # To prevent this, we do not allow fallbacking when the current
  # locale missing a translation is English.
  defp should_fallback?(locale) do
    locale != "en"
  end

  @impl true
  def handle_missing_translation(locale, domain, msgctxt, msgid, bindings) do
    next = next_locale(locale, Pleroma.Web.GettextCompanion.get_locales())

    if is_nil(next) or not should_fallback?(locale) do
      super(locale, domain, msgctxt, msgid, bindings)
    else
      {:ok,
       Gettext.with_locale(next, fn ->
         Gettext.dpgettext(Pleroma.Web.Gettext, domain, msgctxt, msgid, bindings)
       end)}
    end
  end

  @impl true
  def handle_missing_plural_translation(
        locale,
        domain,
        msgctxt,
        msgid,
        msgid_plural,
        n,
        bindings
      ) do
    next = next_locale(locale, Pleroma.Web.GettextCompanion.get_locales())

    if is_nil(next) or not should_fallback?(locale) do
      super(locale, domain, msgctxt, msgid, msgid_plural, n, bindings)
    else
      {:ok,
       Gettext.with_locale(next, fn ->
         Gettext.dpngettext(
           Pleroma.Web.Gettext,
           domain,
           msgctxt,
           msgid,
           msgid_plural,
           n,
           bindings
         )
       end)}
    end
  end
end
