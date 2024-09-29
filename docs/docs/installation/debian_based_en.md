# Installing on Debian Based Distributions

{! installation/otp_vs_from_source_source.include !}

## Installation

This guide will assume you are on Debian 12 (“bookworm”) or later. This guide should also work with Ubuntu 22.04 (“Jammy Jellyfish”) and later. It also assumes that you have administrative rights, either as root or a user with [sudo permissions](https://www.digitalocean.com/community/tutorials/how-to-add-delete-and-grant-sudo-privileges-to-users-on-a-debian-vps). If you want to run this guide with root, ignore the `sudo` at the beginning of the lines, unless it calls a user like `sudo -Hu akkoma`; in this case, use `su <username> -s $SHELL -c 'command'` instead.

{! installation/generic_dependencies.include !}

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

### Create the akkoma user

* Add a new system user for the Akkoma service:

```shell
sudo useradd -r -s /bin/false -m -d /var/lib/akkoma -U akkoma
```

**Note**: To execute a single command as the Akkoma system user, use `sudo -Hu akkoma command`. You can also switch to a shell by using `sudo -Hu akkoma $SHELL`. If you don’t have and want `sudo` on your system, you can use `su` as root user (UID 0) for a single command by using `su -l akkoma -s $SHELL -c 'command'` and `su -l akkoma -s $SHELL` for starting a shell.

### Install Elixir and Erlang

If your distribution packages a recent enough version of Elixir, you can install it directly from the distro repositories and skip to the next section of the guide:

```shell
sudo apt install elixir erlang-dev erlang-nox
```

Otherwise use [asdf](https://github.com/asdf-vm/asdf) to install the latest versions of Elixir and Erlang.

First, install some dependencies needed to build Elixir and Erlang:
```shell
sudo apt install curl unzip build-essential autoconf m4 libncurses5-dev libssh-dev unixodbc-dev xsltproc libxml2-utils libncurses-dev
```

Then login to the `akkoma` user and install asdf:
```shell
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.3
```

Add the following lines to `~/.bashrc`:
```shell
. "$HOME/.asdf/asdf.sh"
# asdf completions
. "$HOME/.asdf/completions/asdf.bash"
```

Restart the shell:
```shell
exec $SHELL
```

Next install Erlang:
```shell
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
export KERL_CONFIGURE_OPTIONS="--disable-debug --without-javac"
asdf install erlang 25.3.2.5
asdf global erlang 25.3.2.5
```

Now install Elixir:
```shell
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf install elixir 1.15.4-otp-25
asdf global elixir 1.15.4-otp-25
```

Confirm that Elixir is installed correctly by checking the version:
```shell
elixir --version
```

### Optional packages: [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md)

```shell
sudo apt install imagemagick ffmpeg libimage-exiftool-perl
```

### Install AkkomaBE

* Log into the `akkoma` user and clone the AkkomaBE repository from the stable branch and make the Akkoma user the owner of the directory:

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
sudo apt install nginx
```

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

* Setup your SSL cert, using your method of choice or certbot. If using certbot, first install it:

```shell
sudo apt install certbot python3-certbot-nginx
```

and then set it up:

```shell
sudo mkdir -p /var/lib/letsencrypt/
sudo certbot --email <your@emailaddress> -d <yourdomain> -d <media_domain> --nginx
```

If that doesn't work the first time, add `--dry-run` to further attempts to avoid being ratelimited as you identify the issue, and do not remove it until the dry run succeeds. A common source of problems are nginx config syntax errors; this can be checked for by running `nginx -t`.

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
