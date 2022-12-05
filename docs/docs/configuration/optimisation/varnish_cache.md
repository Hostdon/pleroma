# Using a Varnish Cache

Varnish is a layer that sits between your web server and your backend application -
it does something similar to nginx caching, but tends to be optimised for speed over
all else.

To set up a varnish cache, first you'll need to install varnish. 

This will vary by distribution, and since this is a rather advanced guide,
no copy-paste instructions are provided. It's probably in your distribution's
package manager, though. `apt-get install varnish` and so on.

Once you have varnish installed, you'll need to configure it to work with akkoma.

Copy the configuration file to the varnish configuration directory:

    cp installation/akkoma.vcl /etc/varnish/akkoma.vcl

You may want to check if varnish added a `default.vcl` file to the same directory,
if so you can just remove it without issue.

Then boot up varnish, probably `systemctl start varnish` or `service varnish start`.

Now you should be able to `curl -D- localhost:6081` and see a bunch of
akkoma javascript.

Once that's out of the way, we can point our webserver at varnish. This

=== "Nginx"

    upstream phoenix {
        server 127.0.0.1:6081 max_fails=5 fail_timeout=60s;
    }


=== "Caddy"

    reverse_proxy 127.0.0.1:6081

Now hopefully it all works

If you get a HTTPS redirect loop, you may need to remove this part of the VCL

```vcl
if (std.port(server.ip) != 443) {
      set req.http.X-Forwarded-Proto = "http";
      set req.http.x-redir = "https://" + req.http.host + req.url;
      return (synth(750, ""));
} else {
  set req.http.X-Forwarded-Proto = "https";
}
```

This will allow your webserver alone to handle redirects.