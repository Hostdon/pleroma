# Akkoma: Magically expressive social media
# Copyright © 2026 Akkoma Authors <https://akkoma.dev/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule HttpRequestMockMacros do
  defmacro mock_masto_webfinger(urls, nick, webfinger_domain, ap_domain \\ nil, ap_id \\ nil) do
    urls = if is_binary(urls), do: [urls], else: urls

    for url <- urls do
      quote do
        def get(unquote(url) = url, _, _, _) do
          webfinger_response_masto(
            url,
            unquote(nick),
            unquote(webfinger_domain),
            unquote(ap_domain),
            unquote(ap_id)
          )
        end
      end
    end
  end
end
