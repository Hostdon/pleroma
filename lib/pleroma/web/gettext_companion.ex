# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.GettextCompanion do
  @moduledoc """
  Akkoma-specific functions controlling the Gettext backend or general utility for interfacing with it
  """

  @doc "Sets the passed locales as possible translation languages for strings; ordered by preference."
  def put_locales(locales) do
    if is_locale_list(locales) do
      Process.put({Pleroma.Web.Gettext, :locales}, Enum.uniq(locales))
      Gettext.put_locale(Enum.at(locales, 0, Gettext.get_locale()))
      :ok
    else
      {:error, :not_locale_list}
    end
  end

  # Public for usage in tests
  def get_locales do
    Process.get({Pleroma.Web.Gettext, :locales}, [])
  end

  @doc """
  Ensures all entries can fallback to other locales without or with a different variant tag
  by appending additional entries where needed and alternatives are supported by the backend.
  """
  def ensure_fallbacks(locales) do
    locales
    |> Enum.flat_map(fn locale ->
      others =
        other_supported_variants_of_locale(locale)
        |> Enum.filter(fn l -> not Enum.member?(locales, l) end)

      [locale] ++ others
    end)
  end

  @doc "Converts simple BCP-47 format langauge specifiers into Gettext locale specifier format"
  def normalize_locale(locale) do
    if is_binary(locale) do
      String.replace(locale, "-", "_", global: true)
    else
      nil
    end
  end

  @doc "Converts a Gettext locale specifier into a BCP-47 language tag as used in HTML"
  def language_tag do
    # Naive implementation: HTML lang attribute uses BCP 47, which
    # uses - as a separator.
    # https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/lang

    Gettext.get_locale()
    |> String.replace("_", "-", global: true)
  end

  @doc "Checks whether the given locale has translations in Akkoma"
  def supports_locale?(locale) do
    Pleroma.Web.Gettext
    |> Gettext.known_locales()
    |> Enum.member?(locale)
  end

  # used by macro
  def with_locales_func(locales, fun) do
    prev_locales = Process.get({Pleroma.Web.Gettext, :locales})
    put_locales(locales)

    try do
      fun.()
    after
      if prev_locales do
        put_locales(prev_locales)
      else
        Process.delete({Pleroma.Web.Gettext, :locales})
        Process.delete(Gettext)
      end
    end
  end

  @doc "Temporarily changes the translation locale of the current process"
  defmacro with_locales(locales, do: fun) do
    quote do
      Pleroma.Web.GettextCompanion.with_locales_func(unquote(locales), fn ->
        unquote(fun)
      end)
    end
  end

  # used by macro
  def to_locale_list(locale) when is_binary(locale) do
    locale
    |> String.split(",")
    |> Enum.filter(&supports_locale?/1)
  end

  def to_locale_list(_), do: []

  @doc "Temporarily changes the translation locale of the current process, allowing fallback to the default locale."
  defmacro with_locale_or_default(locale, do: fun) do
    quote do
      Pleroma.Web.GettextCompanion.with_locales_func(
        Pleroma.Web.GettextCompanion.to_locale_list(unquote(locale))
        |> Enum.concat(Pleroma.Web.GettextCompanion.get_locales()),
        fn ->
          unquote(fun)
        end
      )
    end
  end

  defp is_locale_list(locales) do
    Enum.all?(locales, &is_binary/1)
  end

  defp variant?(locale), do: String.contains?(locale, "_")

  defp language_for_variant(locale) do
    Enum.at(String.split(locale, "_"), 0)
  end

  defp other_supported_variants_of_locale(locale) do
    cond do
      supports_locale?(locale) ->
        []

      variant?(locale) ->
        lang = language_for_variant(locale)
        if supports_locale?(lang), do: [lang], else: []

      true ->
        Gettext.known_locales(Pleroma.Web.Gettext)
        |> Enum.filter(fn l -> String.starts_with?(l, locale <> "_") end)
    end
  end
end
