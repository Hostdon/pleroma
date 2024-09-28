# Storing Remote Media

Akkoma does not store remote/federated media by default. The best way to achieve this is to change Nginx to keep its reverse proxy cache
for a year and to activate the `MediaProxyWarmingPolicy` MRF policy in Akkoma which will automatically fetch all media through the proxy
as soon as the post is received by your instance.

## Nginx

The following are excerpts from the [suggested nginx config](../../../installation/nginx/akkoma.nginx) that demonstrates the necessary config for the media proxy to work.

A `proxy_cache_path` must be defined, for example:

```
proxy_cache_path /long/term/storage/path/akkoma-media-cache levels=1:2
    keys_zone=akkoma_media_cache:10m inactive=1y use_temp_path=off;
```

The `proxy_cache_path` must then be configured for use with media proxy paths:

```
    location ~ ^/(media|proxy) {
        proxy_cache        akkoma_media_cache;
        slice              1m;
        proxy_cache_key    $host$uri$is_args$args$slice_range;
        proxy_set_header   Range $slice_range;
        proxy_cache_valid  200 206 301 304 1h;
        proxy_cache_lock   on;
        proxy_ignore_client_abort on;
        proxy_buffering    on;
        chunked_transfer_encoding on;
        proxy_pass         http://phoenix;
    }
}
```

Ensure that `proxy_http_version 1.1;` is set for the above `location` block. In the suggested config, this is already the case.

## Akkoma

### File-based Configuration

If you're using static file configuration, add the `MediaProxyWarmingPolicy` to your MRF policies. For example:

```
config :pleroma, :mrf,
  policies: [Pleroma.Web.ActivityPub.MRF.MediaProxyWarmingPolicy]
```

### Database Configuration

In the admin interface, add `MediaProxyWarmingPolicy` to the `Policies` option under `Settings` → `MRF`.
