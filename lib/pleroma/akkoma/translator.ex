defmodule Pleroma.Akkoma.Translator do
  @cachex Pleroma.Config.get([:cachex, :provider], Cachex)

  def languages do
    module = Pleroma.Config.get([:translator, :module])

    @cachex.fetch!(:translations_cache, "languages:#{module}}", fn _ ->
      with {_, true} <- {:enabled, Pleroma.Config.get([:translator, :enabled])},
           {:ok, source_languages, dest_languages} <- module.languages() do
        {:commit, {:ok, source_languages, dest_languages}}
      else
        {:enabled, _} -> {:commit, {:enabled, false}}
        {:error, err} -> {:ignore, {:error, err}}
      end
    end)
  end
end
