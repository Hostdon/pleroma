# Easy Onion Federation (Tor)
Tor can free people from the necessity of a domain, in addition to helping protect their privacy. As Akkoma's goal is to empower the people and let as many as possible host an instance with as little resources as possible, the ability to host an instance with a small, cheap computer like a Raspberry Pi along with Tor, would be a great way to achieve that.
In addition, federating with such instances will also help furthering that goal.

This is a guide to show you how it can be easily done.

This guide assumes you already got Akkoma working, and that it's running on the default port 4000.
This guide also assumes you're using Nginx as the reverse proxy.

To install Tor on Debian / Ubuntu:
```
apt -yq install tor
```

**WARNING:** Onion instances not using a Tor version supporting V3 addresses will not be able to federate with you. 

Create the hidden service for your Akkoma instance in `/etc/tor/torrc`, with an HTTP tunnel:
```
HiddenServiceDir /var/lib/tor/akkoma_hidden_service/
HiddenServicePort 80 127.0.0.1:8099
HiddenServiceVersion 3  # Remove if Tor version is below 0.3 ( tor --version )
HTTPTunnelPort 9080
```
Restart Tor to generate an adress:
```
systemctl restart tor@default.service
```
Get the address:
```
cat /var/lib/tor/akkoma_hidden_service/hostname
```

# Federation

Next, edit your Akkoma config.
If running in prod, navigate to your Akkoma directory, edit `config/prod.secret.exs`
and append this line:
```
config :pleroma, :http, proxy_url: "http://localhost:9080"
```
In your Akkoma directory, assuming you're running prod,
run the following:
```
su akkoma
MIX_ENV=prod mix deps.get
MIX_ENV=prod mix ecto.migrate
exit
```
restart Akkoma (if using systemd):
```
systemctl restart akkoma
```

# Tor Instance Access

Make your instance accessible using Tor.

## Tor-only Instance
If creating a Tor-only instance, open `config/prod.secret.exs` and under "config :pleroma, Akkoma.Web.Endpoint," edit "https" and "port: 443" to the following:
```
   url: [host: "onionaddress", scheme: "http", port: 80],
```
In addition to that, replace the existing nginx config's contents with the example below.

## Existing Instance (Clearnet Instance)
If not a Tor-only instance, 
add the nginx config below to your existing config at `/etc/nginx/sites-enabled/akkoma.nginx`.

---
For both cases, disable CSP in Akkoma's config (STS is disabled by default) so you can define those yourself separately from the clearnet (if your instance is also on the clearnet).
Copy the following into the `config/prod.secret.exs` in your Akkoma folder (/home/akkoma/akkoma/):
```
config :pleroma, :http_security,
  enabled: false
```

Use this as the Nginx config:
```
proxy_cache_path /tmp/akkoma-media-cache levels=1:2 keys_zone=akkoma_media_cache:10m max_size=10g inactive=720m use_temp_path=off;
# The above already exists in a clearnet instance's config.
# If not, add it.

server {
    listen 127.0.0.1:8099;
    server_name youronionaddress;

    # Comment to enable logs
    access_log /dev/null;
    error_log /dev/null;

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript application/activity+json application/atom+xml;

    client_max_body_size 16m;

    location / {

        add_header X-XSS-Protection "0";
        add_header X-Permitted-Cross-Domain-Policies none;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header Referrer-Policy same-origin;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;

        proxy_pass http://localhost:4000;

        client_max_body_size 16m;
    }

    location /proxy {
        proxy_cache akkoma_media_cache;
        proxy_cache_lock on;
        proxy_ignore_client_abort on;
        proxy_pass http://localhost:4000;
    }
}
```
reload Nginx:
```
systemctl reload nginx
```

You should now be able to both access your instance using Tor and federate with other Tor instances!

---

### Possible Issues

* In Debian, make sure your hidden service folder `/var/lib/tor/akkoma_hidden_service/` and its contents, has debian-tor as both owner and group by using 
```
ls -la /var/lib/tor/
```
If it's not, run:
```
chown -R debian-tor:debian-tor /var/lib/tor/akkoma_hidden_service/
```
* Make sure *only* the owner has *only* read and write permissions.
If not, run:
```
chmod -R 600 /var/lib/tor/akkoma_hidden_service/
```
* If you have trouble logging in to the Mastodon Frontend when using Tor, use the Tor Browser Bundle.
