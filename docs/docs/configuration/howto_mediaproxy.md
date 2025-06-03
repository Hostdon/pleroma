# How to activate mediaproxy
## Explanation

Without the `mediaproxy` function, Akkoma doesn't store any remote content like pictures, video etc. locally. So every time you open Akkoma, the content is loaded from the source server, from where the post is coming. This can result in slowly loading content or/and increased bandwidth usage on the source server.
With the `mediaproxy` function you can use nginx to cache this content, so users can access it faster, because it's loaded from your server.

## Activate it

* Set up a subdomain for the proxy with its nginx config on the same machine
* Edit the nginx config for the upload/MediaProxy subdomain to point to the subdomain that has been set up
* Append the following to your `prod.secret.exs` or `dev.secret.exs` (depends on which mode your instance is running):
```elixir
# Replace media.example.td with the subdomain you set up earlier
config :pleroma, :media_proxy,
      enabled: true,
      proxy_opts: [
            redirect_on_failure: true
      ],
      base_url: "https://media.example.tld"
```
You **really** should use a subdomain to serve proxied files; while we will fix bugs resulting from this, serving arbitrary remote content on your main domain namespace is a significant attack surface.

* Restart nginx and Akkoma
