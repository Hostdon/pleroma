# Installing on Arch Linux

{! installation/otp_vs_from_source_source.include !}

## Installation

This guide will assume that you have administrative rights, either as root or a user with [sudo permissions](https://wiki.archlinux.org/index.php/Sudo). If you want to run this guide with root, ignore the `sudo` at the beginning of the lines, unless it calls a user like `sudo -Hu akkoma`; in this case, use `su <username> -s $SHELL -c 'command'` instead.

### Required packages

* `postgresql`
* `elixir`
* `git`
* `base-devel`
* `cmake`
* `file`

#### Optional packages used in this guide

* `nginx` (preferred, example configs for other reverse proxies can be found in the repo)
* `certbot` (or any other ACME client for Let’s Encrypt certificates)
* `ImageMagick`
* `ffmpeg`
* `exiftool`

### Prepare the system

* First update the system, if not already done:

```shell
sudo pacman -Syu
```

* Install some of the above mentioned programs:

```shell
sudo pacman -S git base-devel elixir cmake file
```

### Install PostgreSQL

[Arch Wiki article](https://wiki.archlinux.org/index.php/PostgreSQL)

* Install the `postgresql` package:

```shell
sudo pacman -S postgresql
```

* Initialize the database cluster:

```shell
sudo -iu postgres initdb -D /var/lib/postgres/data
```

* Start and enable the `postgresql.service`

```shell
sudo systemctl enable --now postgresql.service
```

### Install media / graphics packages (optional, see [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md))

```shell
sudo pacman -S ffmpeg imagemagick perl-image-exiftool
```

### Install AkkomaBE

* Add a new system user for the Akkoma service:

```shell
sudo useradd -r -s /bin/false -m -d /var/lib/akkoma -U akkoma
```

**Note**: To execute a single command as the Akkoma system user, use `sudo -Hu akkoma command`. You can also switch to a shell by using `sudo -Hu akkoma $SHELL`. If you don’t have and want `sudo` on your system, you can use `su` as root user (UID 0) for a single command by using `su -l akkoma -s $SHELL -c 'command'` and `su -l akkoma -s $SHELL` for starting a shell.

* Git clone the AkkomaBE repository from stable-branch and make the Akkoma user the owner of the directory:

```shell
sudo mkdir -p /opt/akkoma
sudo chown -R akkoma:akkoma /opt/akkoma
sudo -Hu akkoma git clone https://akkoma.dev/AkkomaGang/akkoma.git -b stable /opt/akkoma
```

* Change to the new directory:

```shell
cd /opt/akkoma
```

* Install the dependencies for Akkoma and answer with `yes` if it asks you to install `Hex`:

```shell
sudo -Hu akkoma mix deps.get
```

* Generate the configuration: `sudo -Hu akkoma MIX_ENV=prod mix pleroma.instance gen`
  * Answer with `yes` if it asks you to install `rebar3`.
  * This may take some time, because parts of akkoma get compiled first.
  * After that it will ask you a few questions about your instance and generates a configuration file in `config/generated_config.exs`.

* Check the configuration and if all looks right, rename it, so Akkoma will load it (`prod.secret.exs` for productive instances):

```shell
sudo -Hu akkoma mv config/{generated_config.exs,prod.secret.exs}
```

* The previous command creates also the file `config/setup_db.psql`, with which you can create the database:

```shell
sudo -Hu postgres psql -f config/setup_db.psql
```

* Now run the database migration:

```shell
sudo -Hu akkoma MIX_ENV=prod mix ecto.migrate
```

* Now you can start Akkoma already

```shell
sudo -Hu akkoma MIX_ENV=prod mix phx.server
```

### Finalize installation

If you want to open your newly installed instance to the world, you should run nginx or some other webserver/proxy in front of Akkoma and you should consider to create a systemd service file for Akkoma.

#### Nginx

* Install nginx, if not already done:

```shell
sudo pacman -S nginx
```

* Copy the example nginx configuration:

```shell
sudo cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/conf.d/akkoma.conf
```

* Before starting nginx edit the configuration and change it to your needs (e.g. change servername, change cert paths)
* Enable and start nginx:

```shell
sudo systemctl enable --now nginx.service
```

* Setup your SSL cert, using your method of choice or certbot. If using certbot, first install it:

```shell
sudo pacman -S certbot certbot-nginx
```

and then set it up:

```shell
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot --email <your@emailaddress> -d <yourdomain> -d <media_domain> --nginx
```

If that doesn't work the first time, add `--dry-run` to further attempts to avoid being ratelimited as you identify the issue, and do not remove it until the dry run succeeds. A common source of problems are nginx config syntax errors; this can be checked for by running `nginx -t`.

To make sure renewals work, enable the appropriate systemd timer:

```shell
sudo systemctl enable --now certbot-renew.timer
```

Certificate renewal should be handled automatically by Certbot from now on.

#### Other webserver/proxies

You can find example configurations for them in `/opt/akkoma/installation/`.

#### Systemd service

* Copy example service file

```shell
sudo cp /opt/akkoma/installation/akkoma.service /etc/systemd/system/akkoma.service
```

* Edit the service file and make sure that all paths fit your installation
* Enable and start `akkoma.service`:

```shell
sudo systemctl enable --now akkoma.service
```

#### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
sudo -Hu akkoma MIX_ENV=prod mix pleroma.user new <username> <your@emailaddress> --admin
```

{! installation/frontends.include !}

#### Further reading

{! installation/further_reading.include !}

{! support.include !}
