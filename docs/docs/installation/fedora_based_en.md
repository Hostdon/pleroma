# Installing on Fedora

## OTP releases and RedHat-distributions

While the OTP releases of Akkoma work on most Linux distributions, they do not work correctly with RedHat-distributions. Therefore from-source installations are the recommended way to go when trying to install Akkoma on Fedora, Centos Stream or RedHat.

However, it is possible to compile your own OTP release of Akkoma for RedHat. Keep in mind that this has a few drawbacks, and has no particular advantage over a from-source installation, since you'll need to install Erlang and Elixir anyway.

This guide will cover a from-source installation. For instructions on how to build your own OTP release, please check out [the OTP for RedHat guide](./otp_redhat_en.md).

## Installation

This guide will assume you are on Fedora 36. This guide should also work with current releases of Centos Stream and RedHat, although it has not been tested yet. It also assumes that you have administrative rights, either as root or a user with [sudo permissions](https://docs.fedoraproject.org/en-US/quick-docs/adding_user_to_sudoers_file/). If you want to run this guide with root, ignore the `sudo` at the beginning of the lines, unless it calls a user like `sudo -Hu akkoma`; in this case, use `su <username> -s $SHELL -c 'command'` instead.

{! installation/generic_dependencies.include !}

### Prepare the system

* First update the system, if not already done:

```shell
sudo dnf upgrade --refresh
```

* Install some of the above mentioned programs:

```shell
sudo dnf install git gcc g++ make cmake file-devel postgresql-server postgresql-contrib
```

* Enable and initialize Postgres:
```shell
sudo systemctl enable postgresql.service
sudo postgresql-setup --initdb --unit postgresql
# Allow password auth for postgres
sudo sed -E -i 's|(host +all +all +127.0.0.1/32 +)ident|\1md5|' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl start postgresql.service
```

### Install Elixir and Erlang

* Install Elixir and Erlang:

```shell
sudo dnf install elixir erlang-os_mon erlang-eldap erlang-xmerl erlang-erl_interface erlang-syntax_tools
```


### Optional packages: [`docs/installation/optional/media_graphics_packages.md`](../installation/optional/media_graphics_packages.md)

* Install ffmpeg (requires setting up the RPM-fusion repositories):

```shell
sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf -y install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install ffmpeg
```

* Install ImageMagick and ExifTool for image manipulation:

```shell
sudo dnf install Imagemagick perl-Image-ExifTool
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
sudo dnf install nginx
```

* Setup your SSL cert, using your method of choice or certbot. If using certbot, first install it:

```shell
sudo dnf install certbot
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
sudo cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/conf.d/akkoma.conf
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

{! installation/further_reading.include !}

{! support.include !}
