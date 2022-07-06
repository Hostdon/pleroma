# Installing on NetBSD

{! backend/installation/generic_dependencies.include !}

## Installing software used in this guide

pkgin should have been installed by the NetBSD installer if you selected
the right options. If it isn't installed, install it using pkg_add.

Note that `postgresql11-contrib` is needed for the Postgres extensions
Akkoma uses.

The `mksh` shell is needed to run the Elixir `mix` script.

`# pkgin install acmesh elixir git-base git-docs mksh nginx postgresql11-server postgresql11-client postgresql11-contrib sudo ffmpeg4 ImageMagick`

You can also build these packages using pkgsrc:
```
databases/postgresql11-contrib
databases/postgresql11-client
databases/postgresql11-server
devel/git-base
devel/git-docs
devel/cmake
lang/elixir
security/acmesh
security/sudo
shells/mksh
www/nginx
```

Copy the rc.d scripts to the right directory:

```
# cp /usr/pkg/share/examples/rc.d/nginx /usr/pkg/share/examples/rc.d/pgsql /etc/rc.d
```

Add nginx and Postgres to `/etc/rc.conf`:

```
nginx=YES
pgsql=YES
```

## Configuring postgres

First, run `# /etc/rc.d/pgsql start`. Then, `$ sudo -Hu pgsql -g pgsql createdb`.

### Install media / graphics packages (optional, see [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md))

`# pkgin install ImageMagick ffmpeg4 p5-Image-ExifTool`

## Configuring Akkoma

Create a user for Akkoma:

```
# groupadd akkoma
# useradd -d /home/akkoma -m -g akkoma -s /usr/pkg/bin/mksh akkoma
# echo 'export LC_ALL="en_GB.UTF-8"' >> /home/akkoma/.profile
# su -l akkoma -c $SHELL
```

Clone the repository:

```
$ cd /home/akkoma
$ git clone https://akkoma.dev/AkkomaGang/akkoma.git
```

Configure Akkoma. Note that you need a domain name at this point:

```
$ cd /home/akkoma/akkoma
$ mix deps.get
$ MIX_ENV=prod mix pleroma.instance gen # You will be asked a few questions here.
```

Since Postgres is configured, we can now initialize the database. There should
now be a file in `config/setup_db.psql` that makes this easier. Edit it, and
*change the password* to a password of your choice. Make sure it is secure, since
it'll be protecting your database. Now initialize the database:

```
$ sudo -Hu pgsql -g pgsql psql -f config/setup_db.psql
```

Postgres allows connections from all users without a password by default. To
fix this, edit `/usr/pkg/pgsql/data/pg_hba.conf`. Change every `trust` to
`password`.

Once this is done, restart Postgres with `# /etc/rc.d/pgsql restart`.

Run the database migrations.
You will need to do this whenever you update with `git pull`:

```
$ MIX_ENV=prod mix ecto.migrate
```

## Configuring nginx

Install the example configuration file
`/home/akkoma/akkoma/installation/nginx/akkoma.nginx` to
`/usr/pkg/etc/nginx.conf`.

Note that it will need to be wrapped in a `http {}` block. You should add
settings for the nginx daemon outside of the http block, for example:

```
user                    nginx  nginx;
error_log               /var/log/nginx/error.log;
worker_processes        4;

events {
}
```

Edit the defaults:

* Change `ssl_certificate` and `ssl_trusted_certificate` to
`/etc/nginx/tls/fullchain`.
* Change `ssl_certificate_key` to `/etc/nginx/tls/key`.
* Change `example.tld` to your instance's domain name.

## Configuring acme.sh

We'll be using acme.sh in Stateless Mode for TLS certificate renewal.

First, get your account fingerprint:

```
$ sudo -Hu nginx -g nginx acme.sh --register-account
```

You need to add the following to your nginx configuration for the server
running on port 80:

```
  location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
    default_type text/plain;
    return 200 "$1.6fXAG9VyG0IahirPEU2ZerUtItW2DHzDzD9wZaEKpqd";
  }
```

Replace the string after after `$1.` with your fingerprint.

Start nginx:

```
# /etc/rc.d/nginx start
```

It should now be possible to issue a cert (replace `example.com`
with your domain name):

```
$ sudo -Hu nginx -g nginx acme.sh --issue -d example.com --stateless
```

Let's add auto-renewal to `/etc/daily.local`
(replace `example.com` with your domain):

```
/usr/pkg/bin/sudo -Hu nginx -g nginx \
    /usr/pkg/sbin/acme.sh -r \
    -d example.com \
    --cert-file /etc/nginx/tls/cert \
    --key-file /etc/nginx/tls/key \
    --ca-file /etc/nginx/tls/ca \
    --fullchain-file /etc/nginx/tls/fullchain \
    --stateless
```

## Creating a startup script for Akkoma

Copy the startup script to the correct location and make sure it's executable:

```
# cp /home/akkoma/akkoma/installation/netbsd/rc.d/akkoma /etc/rc.d/akkoma
# chmod +x /etc/rc.d/akkoma
```

Add the following to `/etc/rc.conf`:

```
akkoma=YES
akkoma_home="/home/akkoma"
akkoma_user="akkoma"
```

Run `# /etc/rc.d/akkoma start` to start Akkoma.

## Conclusion

Restart nginx with `# /etc/rc.d/nginx restart` and you should be up and running.

Make sure your time is in sync, or other instances will receive your posts with
incorrect timestamps. You should have ntpd running.

## Instances running NetBSD

* <https://catgirl.science>

#### Further reading

{! backend/installation/further_reading.include !}

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:libera.chat](https://matrix.to/#/#pleroma:libera.chat) via Matrix or **#pleroma** on **libera.chat** via IRC.
## Questions

If you encounter any issues or have questions regarding the install process, feel free to ask at [meta.akkoma.dev](https://meta.akkoma.dev/).
