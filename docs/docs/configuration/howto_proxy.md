# How to configure upstream proxy for federation
If you want to proxify all http requests (e.g. for TOR) that Akkoma makes to an upstream proxy server, edit your config file (`dev.secret.exs` or `prod.secret.exs`) and add the following:

```
config :pleroma, :http,
  proxy_url: "127.0.0.1:8123"
```

The other way to do it, for example, with Tor can be done like so:
```
config :pleroma, :http, proxy_url: {:socks5, :localhost, 9050}
```
