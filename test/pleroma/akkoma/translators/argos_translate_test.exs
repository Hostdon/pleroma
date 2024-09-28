defmodule Pleroma.Akkoma.Translators.ArgosTranslateTest do
  alias Pleroma.Akkoma.Translators.ArgosTranslate

  import Mock

  use Pleroma.DataCase, async: true

  setup do
    clear_config([:argos_translate, :command_argos_translate], "argos-translate_test")
    clear_config([:argos_translate, :command_argospm], "argospm_test")
  end

  test "it lists available languages" do
    languages =
      with_mock System, [:passthrough],
        cmd: fn "argospm_test", ["list"], _ ->
          {"translate-nl_en\ntranslate-en_nl\ntranslate-ja_en\n", 0}
        end do
        ArgosTranslate.languages()
      end

    assert {:ok, source_langs, dest_langs} = languages

    assert [%{code: "en", name: "en"}, %{code: "ja", name: "ja"}, %{code: "nl", name: "nl"}] =
             source_langs |> Enum.sort()

    assert [%{code: "en", name: "en"}, %{code: "nl", name: "nl"}] = dest_langs |> Enum.sort()
  end

  test "it translates from the to language when no language is set and returns the text unchanged" do
    assert {:ok, "nl", "blabla"} = ArgosTranslate.translate("blabla", nil, "nl")
  end

  test "it translates from the provided language if provided" do
    translation_response =
      with_mock System, [:passthrough],
        cmd: fn "argos-translate_test", ["--from-lang", "nl", "--to-lang", "en", "blabla"], _ ->
          {"yadayada", 0}
        end do
        ArgosTranslate.translate("blabla", "nl", "en")
      end

    assert {:ok, "nl", "yadayada"} = translation_response
  end

  test "it returns a proper error when the executable can't be found" do
    non_existing_command = "sfqsfgqsefd"
    clear_config([:argos_translate, :command_argos_translate], non_existing_command)
    clear_config([:argos_translate, :command_argospm], non_existing_command)

    assert nil == System.find_executable(non_existing_command)

    assert {:error, "ArgosTranslate failed to fetch languages" <> _} = ArgosTranslate.languages()

    assert {:error, "ArgosTranslate failed to translate" <> _} =
             ArgosTranslate.translate("blabla", "nl", "en")
  end

  test "it can strip html" do
    content =
      ~s[<p>What&#39;s up my fellow fedizens?</p><p>So anyway</p><ul><li><a class="hashtag" data-tag="cofe" href="https://suya.space/tag/cofe">#cofe</a></li><li><a class="hashtag" data-tag="suya" href="https://cofe.space/tag/suya">#Suya</a></li></ul><p>ammiright!<br/>:ablobfoxhyper:</p>]

    stripped_content =
      "\nWhat's up my fellow fedizens?\n\nSo anyway\n\n#cofe\n#Suya\nammiright!\n:ablobfoxhyper:\n"

    expected_response_strip_html =
      "<br/>What&#39;s up my fellow fedizens?<br/><br/>So anyway<br/><br/>#cofe<br/>#Suya<br/>ammiright!<br/>:ablobfoxhyper:<br/>"

    response_strip_html =
      with_mock System, [:passthrough],
        cmd: fn "argos-translate_test",
                ["--from-lang", _, "--to-lang", _, ^stripped_content],
                _ ->
          {stripped_content, 0}
        end do
        ArgosTranslate.translate(content, "nl", "en")
      end

    clear_config([:argos_translate, :strip_html], false)

    response_no_strip_html =
      with_mock System, [:passthrough],
        cmd: fn "argos-translate_test", ["--from-lang", _, "--to-lang", _, string], _ ->
          {string, 0}
        end do
        ArgosTranslate.translate(content, "nl", "en")
      end

    assert {:ok, "nl", content} == response_no_strip_html

    assert {:ok, "nl", expected_response_strip_html} == response_strip_html
  end
end
