defmodule Pleroma.Akkoma.Translator.Provider do
  @callback translate(String.t(), String.t() | nil, String.t()) ::
              {:ok, String.t(), String.t()} | {:error, any()}
  @callback languages() ::
              {:ok, [%{name: String.t(), code: String.t()}],
               [%{name: String.t(), code: String.t()}]}
              | {:error, any()}
  @callback name() :: String.t()
end
