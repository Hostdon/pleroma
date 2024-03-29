# Installing on Alpine Linux

{! backend/installation/otp_vs_from_source_source.include !}

## Installation

This guide is a step-by-step installation guide for Alpine Linux. The instructions were verified against Alpine v3.10 standard image. You might miss additional dependencies if you use `netboot` instead.

It assumes that you have administrative rights, either as root or a user with [sudo permissions](https://www.linode.com/docs/tools-reference/custom-kernels-distros/install-alpine-linux-on-your-linode/#configuration). If you want to run this guide with root, ignore the `sudo` at the beginning of the lines, unless it calls a user like `sudo -Hu pleroma`; in this case, use `su -l <username> -s $SHELL -c 'command'` instead.

{! backend/installation/generic_dependencies.include !}

### Prepare the system

* The community repository must be enabled in `/etc/apk/repositories`. Depending on which version and mirror you use this looks like `http://alpine.42.fr/v3.10/community`. If you autogenerated the mirror during installation:

```shell
awk 'NR==2' /etc/apk/repositories | sed 's/main/community/' | tee -a /etc/apk/repositories
```

* Then update the system, if not already done:

```shell
sudo apk update
sudo apk upgrade
```

* Install some tools, which are needed later:

```shell
sudo apk add git build-base cmake file-dev
```

### Install Elixir and Erlang

* Install Erlang and Elixir:

```shell
sudo apk add erlang erlang-runtime-tools erlang-xmerl elixir
```

* Install `erlang-eldap` if you want to enable ldap authenticator

```shell
sudo apk add erlang-eldap
```

### Install PostgreSQL

* Install Postgresql server:

```shell
sudo apk add postgresql postgresql-contrib
```

* Initialize database:

```shell
sudo /etc/init.d/postgresql start
```

* Enable and start postgresql server:

```shell
sudo rc-update add postgresql
```

### Install media / graphics packages (optional, see [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md))

```shell
sudo apk add ffmpeg imagemagick exiftool
```

### Install PleromaBE

* Add a new system user for the Pleroma service:

```shell
sudo addgroup pleroma
sudo adduser -S -s /bin/false -h /opt/pleroma -H -G pleroma pleroma
```

**Note**: To execute a single command as the Pleroma system user, use `sudo -Hu pleroma command`. You can also switch to a shell by using `sudo -Hu pleroma $SHELL`. If you don’t have and want `sudo` on your system, you can use `su` as root user (UID 0) for a single command by using `su -l pleroma -s $SHELL -c 'command'` and `su -l pleroma -s $SHELL` for starting a shell.

* Git clone the PleromaBE repository and make the Pleroma user the owner of the directory:

```shell
sudo mkdir -p /opt/pleroma
sudo chown -R pleroma:pleroma /opt/pleroma
sudo -Hu pleroma git clone -b stable https://git.pleroma.social/pleroma/pleroma /opt/pleroma
```

* Change to the new directory:

```shell
cd /opt/pleroma
```

* Install the dependencies for Pleroma and answer with `yes` if it asks you to install `Hex`:

```shell
sudo -Hu pleroma mix deps.get
```

* Generate the configuration: `sudo -Hu pleroma MIX_ENV=prod mix pleroma.instance gen`
  * Answer with `yes` if it asks you to install `rebar3`.
  * This may take some time, because parts of pleroma get compiled first.
  * After that it will ask you a few questions about your instance and generates a configuration file in `config/generated_config.exs`.

* Check the configuration and if all looks right, rename it, so Pleroma will load it (`prod.secret.exs` for productive instance, `dev.secret.exs` for development instances):

```shell
sudo -Hu pleroma mv config/{generated_config.exs,prod.secret.exs}
```

* The previous command creates also the file `config/setup_db.psql`, with which you can create the database:

```shell
sudo -Hu postgres psql -f config/setup_db.psql
```

* Now run the database migration:

```shell
sudo -Hu pleroma MIX_ENV=prod mix ecto.migrate
```

* Now you can start Pleroma already

```shell
sudo -Hu pleroma MIX_ENV=prod mix phx.server
```

### Finalize installation

If you want to open your newly installed instance to the world, you should run nginx or some other webserver/proxy in front of Pleroma and you should consider to create an OpenRC service file for Pleroma.

#### Nginx

* Install nginx, if not already done:

```shell
sudo apk add nginx
```

* Setup your SSL cert, using your method of choice or certbot. If using certbot, first install it:

```shell
sudo apk add certbot
```

and then set it up:

```shell
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --standalone
```

If that doesn’t work, make sure, that nginx is not already running. If it still doesn’t work, try setting up nginx first (change ssl “on” to “off” and try again).

* Copy the example nginx configuration to the nginx folder

```shell
sudo cp /opt/pleroma/installation/pleroma.nginx /etc/nginx/conf.d/pleroma.conf
```

* Before starting nginx edit the configuration and change it to your needs. You must change change `server_name` and the paths to the certificates. You can use `nano` (install with `apk add nano` if missing).

```
server {
    server_name    your.domain;
    listen         80;
    ...
}

server {
    server_name your.domain;
    listen 443 ssl http2;
    ...
    ssl_trusted_certificate   /etc/letsencrypt/live/your.domain/chain.pem;
    ssl_certificate           /etc/letsencrypt/live/your.domain/fullchain.pem;
    ssl_certificate_key       /etc/letsencrypt/live/your.domain/privkey.pem;
    ...
}
```

* Enable and start nginx:

```shell
sudo rc-update add nginx
sudo service nginx start
```

If you need to renew the certificate in the future, uncomment the relevant location block in the nginx config and run:

```shell
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --webroot -w /var/lib/letsencrypt/
```

#### OpenRC service

* Copy example service file:

```shell
sudo cp /opt/pleroma/installation/init.d/pleroma /etc/init.d/pleroma
```

* Make sure to start it during the boot

```shell
sudo rc-update add pleroma
```

#### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
sudo -Hu pleroma MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

#### Further reading

{! backend/installation/further_reading.include !}

## Questions

Questions about the installation or didn’t it work as it should be, ask in [#pleroma:libera.chat](https://matrix.to/#/#pleroma:libera.chat) via Matrix or **#pleroma** on **libera.chat** via IRC.
