# Installing on RedHat using OTP releases

## OTP releases and Fedora/RedHat

The current OTP builds available for Linux are unfortunately incompatible with RedHat Linux distributions, like Fedora and Centos Stream. This is due to RedHat maintaining patched versions of certain Erlang libraries, making them incompatible with other Linux distributions.

However, you may compile your own OTP release from scratch. This is particularly useful if you wish to quickly distribute your OTP build onto multiple systems, without having to worry about compiling code on every system. However, if your goal is to simply set up a single instance for yourself, installing from-source might be a simpler option. To install from-source, please follow [this guide](./fedora_based_en.md).


## Pre-requisites

In order to compile a RedHat-compatible OTP release, you will need to run a RedHat Linux distribution. This guide will assume you run Fedora 36, though it should also work on older Fedora releases and other RedHat distributions. It also assumes that you have administrative rights and sufficient knowledge on how to perform common CLI tasks in Linux. If you want to run this guide with root, ignore the `sudo` at the beginning of the lines.

Important: keep in mind that you must build your OTP release for the specific RedHat distribution you wish to use it on. A build on Fedora will only be compatible with a specific Fedora release version.


## Building an OTP release for Fedora 36

### Installing required packages

* First, update your system, if not already done:

```shell
sudo dnf upgrade --refresh
```

* Then install the required packages to build your OTP release:

```shell
sudo dnf install git gcc g++ erlang elixir erlang-os_mon erlang-eldap erlang-xmerl erlang-erl_interface erlang-syntax_tools make cmake file-devel
```


### Preparing the project files

* Git clone the AkkomaBE repository. This can be done anywhere:

```shell
cd ~
git clone https://akkoma.dev/AkkomaGang/akkoma.git -b stable
```

* Change to the new directory:

```shell
cd ./akkoma
```


### Building the OTP release

* Run the following commands:

```shell
export MIX_ENV=prod
echo "import Config" > config/prod.secret.exs
mix local.hex --force
mix local.rebar --force
mix deps.get --only prod
mkdir release
mix release --path release
```

Note that compiling the OTP release will take some time. Once it completes, you will find the OTP files in the directory `release`.

If all went well, you will have built your very own Fedora-compatible OTP release! You can now pack up the files in the `release` directory and deploy them to your other Fedora servers.


## Installing the OTP release

Installing the OTP release from this point onward will be very similar to the regular OTP release. This guide assumes you will want to install your OTP package on other systems, so additional pre-requisites will be listed below.

Please note that running your own OTP release has some minor caveats that you should be aware of. They will be listed below as well.


### Installing required packages

Other than things bundled in the OTP release Akkoma depends on:

* curl (to download the release build)
* ncurses (ERTS won't run without it)
* PostgreSQL (also utilizes extensions in postgresql-contrib)
* nginx (could be swapped with another reverse proxy but this guide covers only it)
* certbot (for Let's Encrypt certificates, could be swapped with another ACME client, but this guide covers only it)
    * If you are using certbot, also install the `python3-certbot-nginx` package for the nginx plugin
* libmagic/file

First, update your system, if not already done:

```shell
sudo dnf upgrade --refresh
```

Then install the required packages:

```shell
sudo dnf install curl ncurses postgresql postgresql-contrib nginx certbot file-devel
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


### Configuring PostgreSQL
#### (Optional) Performance configuration
It is encouraged to check [Optimizing your PostgreSQL performance](../configuration/postgresql.md) document, for tips on PostgreSQL tuning.

Restart PostgreSQL to apply configuration changes:

```shell
sudo systemctl restart postgresql
```

### Installing Akkoma
```sh
# Create a Akkoma user
adduser --system --shell  /bin/false --home /opt/akkoma akkoma

# Move your custom OTP release to the home directory
sudo -Hu akkoma mv /your/custom/otp/release /opt/akkoma

# Create uploads directory and set proper permissions (skip if planning to use a remote uploader)
# Note: It does not have to be `/var/lib/akkoma/uploads`, the config generator will ask about the upload directory later

sudo mkdir -p /var/lib/akkoma/uploads
sudo chown -R akkoma /var/lib/akkoma

# Create custom public files directory (custom emojis, frontend bundle overrides, robots.txt, etc.)
# Note: It does not have to be `/var/lib/akkoma/static`, the config generator will ask about the custom public files directory later
sudo mkdir -p /var/lib/akkoma/static
sudo chown -R akkoma /var/lib/akkoma

# Create a config directory
sudo mkdir -p /etc/akkoma
sudo chown -R akkoma /etc/akkoma

# Run the config generator
sudo -Hu akkoma ./bin/pleroma_ctl instance gen --output /etc/akkoma/config.exs --output-psql /tmp/setup_db.psql

# Create the postgres database
sudo -Hu postgres psql -f /tmp/setup_db.psql

# Create the database schema
sudo -Hu akkoma ./bin/pleroma_ctl migrate

# Start the instance to verify that everything is working as expected
sudo -Hu akkoma ./bin/pleroma daemon

# Wait for about 20 seconds and query the instance endpoint, if it shows your uri, name and email correctly, you are configured correctly
sleep 20 && curl http://localhost:4000/api/v1/instance

# Stop the instance
sudo -Hu akkoma ./bin/pleroma stop
```


### Setting up nginx and getting Let's Encrypt SSL certificaties

#### Copy Akkoma nginx configuration to the nginx folder

```shell
cp /opt/akkoma/installation/akkoma.nginx /etc/nginx/conf.d/akkoma.conf
```

#### Edit the nginx config
```shell
# Replace example.tld with your (sub)domain (replace $EDITOR with your editor of choice)
sudo $EDITOR /etc/nginx/conf.d/akkoma.conf

# Verify that the config is valid
sudo nginx -t
```
#### Start nginx

```shell
sudo systemctl start nginx
```

#### Get a Let's Encrypt certificate

```shell
sudo certbot --email <your@emailaddress> -d <yourdomain> -d <media_domain> --nginx
```

If that doesn't work the first time, add `--dry-run` to further attempts to avoid being ratelimited as you identify the issue, and do not remove it until the dry run succeeds. A common source of problems are nginx config syntax errors; this can be checked for by running `nginx -t`.

If you're successful with obtaining the certificates, opening your (sub)domain in a browser will result in a 502 error, since Akkoma hasn't been started yet.

### Setting up a system service

```shell
# Copy the service into a proper directory
cp /opt/akkoma/installation/akkoma.service /etc/systemd/system/akkoma.service

# Edit the service file and make any neccesary changes
sudo $EDITOR /etc/systemd/system/akkoma.service

# If you use SELinux, set the correct file context on the pleroma binary
sudo semanage fcontext -a -t init_t /opt/akkoma/bin/pleroma
sudo restorecon -v /opt/akkoma/bin/pleroma

# Start akkoma and enable it on boot
sudo systemctl start akkoma
sudo systemctl enable akkoma
```

If everything worked, you should see a response from Akkoma-BE when visiting your domain. You may need to install frontends like Akkoma-FE and Admin-FE; refer to [this guide](../administration/CLI_tasks/frontend.md) on how to install them.

If that didn't happen, try reviewing the installation steps, starting Akkoma in the foreground and seeing if there are any errrors.

{! support.include !}

## Post installation

### Setting up auto-renew of the Let's Encrypt certificate

```shell
# Create the directory for webroot challenges
sudo mkdir -p /var/lib/letsencrypt

# Uncomment the webroot method
sudo $EDITOR /etc/nginx/conf.d/akkoma.conf

# Verify that the config is valid
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Test that renewals work properly
sudo certbot renew --cert-name yourinstance.tld --nginx --dry-run
```

Assuming the commands were run successfully, certbot should be able to renew your certificates automatically via the `certbot-renew.timer` systemd unit.

## Create your first user and set as admin
```shell
cd /opt/akkoma
sudo -Hu akkoma ./bin/pleroma_ctl user new joeuser joeuser@sld.tld --admin
```
This will create an account withe the username of 'joeuser' with the email address of joeuser@sld.tld, and set that user's account as an admin. This will result in a link that you can paste into the browser, which logs you in and enables you to set the password.

## Further reading

### Caveats of building your own OTP release

There are some things to take note of when your are running your own OTP builds.

#### Updating your OTP builds

Using your custom OTP build, you will not be able to update the installation using the `pleroma_ctl update` command. Running this command would overwrite your install with an OTP release from the main Akkoma repository, which will break your install.

Instead, you will have to rebuild your OTP release every time there are updates, then manually move it to where your Akkoma installation is running, overwriting the old OTP release files. Make sure to stop the Akkoma-BE server before overwriting any files!

After that, run the `pleroma_ctl migrate` command as usual to perform database migrations.


#### Cross-compatibility between RedHat distributions

As it currently stands, your OTP build will only be compatible for the specific RedHat distribution you've built it on. Fedora builds only work on Fedora, Centos builds only on Centos, RedHat builds only on RedHat. Secondly, for Fedora, they will also be bound to the specific Fedora release. This is because different releases of Fedora may have significant changes made in some of the required packages and libraries.

{! installation/frontends.include !}

{! installation/further_reading.include !}

{! support.include !}
