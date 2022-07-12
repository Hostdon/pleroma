# Installing on Debian Based Distributions

{! backend/installation/otp_vs_from_source_source.include !}

## Installation

This guide will assume you are on Debian 11 (“bullseye”) or later. This guide should also work with Ubuntu 18.04 (“Bionic Beaver”) and later. It also assumes that you have administrative rights, either as root or a user with [sudo permissions](https://www.digitalocean.com/community/tutorials/how-to-add-delete-and-grant-sudo-privileges-to-users-on-a-debian-vps). If you want to run this guide with root, ignore the `sudo` at the beginning of the lines, unless it calls a user like `sudo -Hu akkoma`; in this case, use `su <username> -s $SHELL -c 'command'` instead.

{! backend/installation/generic_dependencies.include !}

### Prepare the system

* First update the system, if not already done:

```shell
sudo apt update
sudo apt full-upgrade
```

* Install some of the above mentioned programs:

```shell
sudo apt install git build-essential postgresql postgresql-contrib cmake libmagic-dev
```

### Install Elixir and Erlang

* Install Elixir and Erlang (you might need to use backports or [asdf](https://github.com/asdf-vm/asdf) on old systems):

```shell
sudo apt update
sudo apt install elixir erlang-dev erlang-nox
```


### Optional packages: [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md)

```shell
sudo apt install imagemagick ffmpeg libimage-exiftool-perl
```

### Install AkkomaBE

* Add a new system user for the Akkoma service:

```shell
sudo useradd -r -s /bin/false -m -d /var/lib/akkoma -U akkoma
```

**Note**: To execute a single command as the Akkoma system user, use `sudo -Hu akkoma command`. You can also switch to a shell by using `sudo -Hu akkoma $SHELL`. If you don’t have and want `sudo` on your system, you can use `su` as root user (UID 0) for a single command by using `su -l akkoma -s $SHELL -c 'command'` and `su -l akkoma -s $SHELL` for starting a shell.

* Git clone the AkkomaBE repository and make the Akkoma user the owner of the directory:

```shell
sudo mkdir -p /opt/akkoma
sudo chown -R akkoma:akkoma /opt/akkoma
sudo -Hu akkoma git clone https://akkoma.dev/AkkomaGang/akkoma.git /opt/akkoma
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

* Check the configuration and if all looks right, rename it, so Akkoma will load it (`prod.secret.exs` for productive instance, `dev.secret.exs` for development instances):

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
sudo apt install nginx
```

* Setup your SSL cert, using your method of choice or certbot. If using certbot, first install it:

```shell
sudo apt install certbot
```

and then set it up:

```shell
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --standalone
```

If that doesn’t work, make sure, that nginx is not already running. If it still doesn’t work, try setting up nginx first (change ssl “on” to “off” and try again).

---

* Copy the example nginx configuration and activate it:

```shell
sudo cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/sites-available/akkoma.nginx
sudo ln -s /etc/nginx/sites-available/akkoma.nginx /etc/nginx/sites-enabled/akkoma.nginx
```

* Before starting nginx edit the configuration and change it to your needs (e.g. change servername, change cert paths)
* Enable and start nginx:

```shell
sudo systemctl enable --now nginx.service
```

If you need to renew the certificate in the future, uncomment the relevant location block in the nginx config and run:

```shell
sudo certbot certonly --email <your@emailaddress> -d <yourdomain> --webroot -w /var/lib/letsencrypt/
```

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

#### Further reading

{! backend/installation/further_reading.include !}

{! backend/support.include !}
