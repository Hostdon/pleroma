# How to activate mediaproxy
## Explanation

Without the `mediaproxy` function, Akkoma doesn't store any remote content like pictures, video etc. locally. So every time you open Akkoma, the content is loaded from the source server, from where the post is coming. This can result in slowly loading content or/and increased bandwidth usage on the source server.
With the `mediaproxy` function you can use nginx to cache this content, so users can access it faster, because it's loaded from your server.

## Activate it

* Edit your nginx config and add the following location to your main server block:
```
location /proxy {
        return 404;
}
```

* Set up a subdomain for the proxy with its nginx config on the same machine
  *(the latter is not strictly required, but for simplicity we’ll assume so)*
* In this subdomain’s server block add
```
location /proxy {
        proxy_cache akkoma_media_cache;
        proxy_cache_lock on;
        proxy_pass http://localhost:4000;
}
```
Also add the following on top of the configuration, outside of the `server` block:
```
proxy_cache_path /tmp/akkoma-media-cache levels=1:2 keys_zone=akkoma_media_cache:10m max_size=10g inactive=720m use_temp_path=off;
```
If you came here from one of the installation guides, take a look at the example configuration `/installation/nginx/akkoma.nginx`, where this part is already included.

* Append the following to your `prod.secret.exs` or `dev.secret.exs` (depends on which mode your instance is running):
```
config :pleroma, :media_proxy,
      enabled: true,
      proxy_opts: [
            redirect_on_failure: true
      ],
      base_url: "https://cache.akkoma.social"
```
You **really** should use a subdomain to serve proxied files; while we will fix bugs resulting from this, serving arbitrary remote content on your main domain namespace is a significant attack surface.

* Restart nginx and Akkoma
