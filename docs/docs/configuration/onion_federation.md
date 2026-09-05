# Easy Onion Federation (Tor)
Tor can free people from the necessity of a domain, in addition to helping protect their privacy. As Akkoma's goal is to empower the people and let as many as possible host an instance with as little resources as possible, the ability to host an instance with a small, cheap computer like a Raspberry Pi along with Tor, would be a great way to achieve that.
In addition, federating with such instances will also help furthering that goal.

This is a guide to show you how it can be easily done.

This guide assumes you already got Akkoma working, and that it's running on the default port 4000.
This guide also assumes you're using nginx as the reverse proxy.

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
Restart Tor to generate an address:
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

In the nginx config, add the following into the `location /` block:
```nginx
        add_header X-XSS-Protection "0";
        add_header X-Permitted-Cross-Domain-Policies none;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header Referrer-Policy same-origin;
```

Change the `listen` directive to the following:
```nginx
listen 127.0.0.1:8099;
```

Set the `server_name` to your onion address.

Reload nginx:
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
