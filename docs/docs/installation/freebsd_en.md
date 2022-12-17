# Installing on FreeBSD

This document was written for FreeBSD 12.1, but should be work on future releases.

{! installation/generic_dependencies.include !}

## Installing software used in this guide

This assumes the target system has `pkg(8)`.

```
# pkg install elixir postgresql12-server postgresql12-client postgresql12-contrib git-lite sudo nginx gmake acme.sh cmake
```

Copy the rc.d scripts to the right directory:

Setup the required services to automatically start at boot, using `sysrc(8)`.

```
# sysrc nginx_enable=YES
# sysrc postgresql_enable=YES
```

## Initialize postgres

```
# service postgresql initdb
# service postgresql start
```

### Install media / graphics packages (optional, see [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md))

```shell
# pkg install imagemagick ffmpeg p5-Image-ExifTool
```

## Configuring Akkoma

Create a user for Akkoma:

```
# pw add user akkoma -m
# echo 'export LC_ALL="en_US.UTF-8"' >> /home/akkoma/.profile
# su -l akkoma
```

Clone the repository:

```
$ cd $HOME # Should be the same as /home/akkoma
$ git clone https://akkoma.dev/AkkomaGang/akkoma.git
```

Configure Akkoma. Note that you need a domain name at this point:

```
$ cd /home/akkoma/akkoma
$ mix deps.get # Enter "y" when asked to install Hex
$ MIX_ENV=prod mix pleroma.instance gen # You will be asked a few questions here.
$ cp config/generated_config.exs config/prod.secret.exs
```

Since Postgres is configured, we can now initialize the database. There should
now be a file in `config/setup_db.psql` that makes this easier. Edit it, and
*change the password* to a password of your choice. Make sure it is secure, since
it'll be protecting your database. As root, you can now initialize the database:

```
# cd /home/akkoma/akkoma
# sudo -Hu postgres -g postgres psql -f config/setup_db.psql
```

Postgres allows connections from all users without a password by default. To
fix this, edit `/var/db/postgres/data12/pg_hba.conf`. Change every `trust` to
`password`.

Once this is done, restart Postgres with:
```
# service postgresql restart
```

Run the database migrations.

Back as the akkoma user, run the following to implement any database migrations.

```
# su -l akkoma
$ cd /home/akkoma/akkoma
$ MIX_ENV=prod mix ecto.migrate
```

You will need to do this whenever you update with `git pull`:

## Configuring acme.sh

We'll be using acme.sh in Stateless Mode for TLS certificate renewal.

First, as root, allow the user `acme` to have access to the acme log file, as follows:

```
# touch /var/log/acme.sh.log
# chown acme:acme /var/log/acme.sh.log
# chmod 600 /var/log/acme.sh.log
```

Next, obtain your account fingerprint:

```
# sudo -Hu acme -g acme acme.sh --register-account
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
# service nginx start
```

It should now be possible to issue a cert (replace `example.com`
with your domain name):

```
# sudo -Hu acme -g acme acme.sh --issue -d example.com --stateless
```

Let's add auto-renewal to `/etc/crontab`
(replace `example.com` with your domain):

```
/usr/local/bin/sudo -Hu acme -g acme /usr/local/sbin/acme.sh -r -d example.com --stateless
```

### Configuring nginx

FreeBSD's default nginx configuration does not contain an include directive, which is
typically used for multiple sites. Therefore, you will need to first create the required
directory as follows:


```
# mkdir -p /usr/local/etc/nginx/sites-available
```

Next, add an `include` directive to `/usr/local/etc/nginx/nginx.conf`, within the `http {}`
block, as follows:


```
http {
...
	include /usr/local/etc/nginx/sites-available/*;
}
```

As root, copy `/home/akkoma/akkoma/installation/nginx/akkoma.nginx` to
`/usr/local/etc/nginx/sites-available/akkoma.nginx`.

Edit the defaults of `/usr/local/etc/nginx/sites-available/akkoma.nginx`:

* Change `ssl_trusted_certificate` to `/var/db/acme/certs/example.tld/example.tld.cer`.
* Change `ssl_certificate` to `/var/db/acme/certs/example.tld/fullchain.cer`.
* Change `ssl_certificate_key` to `/var/db/acme/certs/example.tld/example.tld.key`.
* Change all references of `example.tld` to your instance's domain name.

## Creating a startup script for Akkoma

Akkoma will need to compile when it initially starts, which typically takes a longer
period of time. Therefore, it is good practice to initially run akkoma from the
command-line before utilizing the rc.d script. That is done as follows:

```
# su -l akkoma
$ cd $HOME/akkoma
$ MIX_ENV=prod mix phx.server
```

Copy the startup script to the correct location and make sure it's executable:

```
# cp /home/akkoma/akkoma/installation/freebsd/rc.d/akkoma /usr/local/etc/rc.d/akkoma
# chmod +x /usr/local/etc/rc.d/akkoma
```

Update the `/etc/rc.conf` and start akkoma with the following commands:

```
# sysrc akkoma_enable=YES
# service akkoma start
```

#### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
sudo -Hu akkoma MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

{! installation/frontends.include !}

## Conclusion

Restart nginx with `# service nginx restart` and you should be up and running.

Make sure your time is in sync, or other instances will receive your posts with
incorrect timestamps. You should have ntpd running.

{! support.include !}
