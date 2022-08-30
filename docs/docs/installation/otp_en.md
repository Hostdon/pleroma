# Installing on Linux using OTP releases

{! installation/otp_vs_from_source.include !}

This guide covers a installation using an OTP release. To install Akkoma from source, please check out the corresponding guide for your distro.

## Pre-requisites
* A machine running Linux with GNU (e.g. Debian, Ubuntu) or musl (e.g. Alpine) libc and `x86_64`, `aarch64` or `armv7l` CPU, you have root access to. If you are not sure if it's compatible see [Detecting flavour section](#detecting-flavour) below
* For installing OTP releases on RedHat-based distros like Fedora and Centos Stream, please follow [this guide](./otp_redhat_en.md) instead.
* A (sub)domain pointed to the machine

You will be running commands as root. If you aren't root already, please elevate your priviledges by executing `sudo su`/`su`.

While in theory OTP releases are possbile to install on any compatible machine, for the sake of simplicity this guide focuses only on Debian/Ubuntu and Alpine.

### Detecting flavour

This is a little more complex than it used to be (thanks ubuntu)

Use the following mapping to figure out your flavour:

| distribution  | flavour      |
| ------------- | ------------ |
| debian stable | amd64        |
| ubuntu focal  | amd64        |
| ubuntu jammy  | ubuntu-jammy |
| alpine        | amd64-musl   |

Other similar distributions will _probably_ work, but if it is not listed above, there is no official
support.

### Installing the required packages

Other than things bundled in the OTP release Akkoma depends on:

* curl (to download the release build)
* unzip (needed to unpack release builds)
* ncurses (ERTS won't run without it)
* PostgreSQL (also utilizes extensions in postgresql-contrib)
* nginx (could be swapped with another reverse proxy but this guide covers only it)
* certbot (for Let's Encrypt certificates, could be swapped with another ACME client, but this guide covers only it)
* libmagic/file

=== "Alpine"
    ```
    awk 'NR==2' /etc/apk/repositories | sed 's/main/community/' | tee -a /etc/apk/repositories
    apk update
    apk add curl unzip ncurses postgresql postgresql-contrib nginx certbot file-dev
    ```

=== "Debian/Ubuntu"
    ```
    apt install curl unzip libncurses5 postgresql postgresql-contrib nginx certbot libmagic-dev
    ```

### Installing optional packages

Per [`docs/installation/optional/media_graphics_packages.md`](optional/media_graphics_packages.md):
  * ImageMagick
  * ffmpeg
  * exiftool

=== "Alpine"
    ```
    apk update
    apk add imagemagick ffmpeg exiftool
    ```

=== "Debian/Ubuntu"
    ```
    apt install imagemagick ffmpeg libimage-exiftool-perl
    ```

## Setup
### Configuring PostgreSQL
#### (Optional) Installing RUM indexes

!!! warning
    It is recommended to use PostgreSQL v11 or newer. We have seen some minor issues with lower PostgreSQL versions.

RUM indexes are an alternative indexing scheme that is not included in PostgreSQL by default. You can read more about them on the [Configuration page](../configuration/cheatsheet.md#rum-indexing-for-full-text-search). They are completely optional and most of the time are not worth it, especially if you are running a single user instance (unless you absolutely need ordered search results).

=== "Alpine"
    ```
    apk add git build-base postgresql-dev
    git clone https://github.com/postgrespro/rum /tmp/rum
    cd /tmp/rum
    make USE_PGXS=1
    make USE_PGXS=1 install
    cd
    rm -r /tmp/rum
    ```

=== "Debian/Ubuntu"
    ```
    # Available only on Buster/19.04
    apt install postgresql-11-rum
    ```

#### (Optional) Performance configuration
It is encouraged to check [Optimizing your PostgreSQL performance](../configuration/postgresql.md) document, for tips on PostgreSQL tuning.

Restart PostgreSQL to apply configuration changes:

=== "Alpine"
    ```
    rc-service postgresql restart
    ```

=== "Debian/Ubuntu"
    ```
    systemctl restart postgresql
    ```

### Installing Akkoma
```sh
# Create a Akkoma user
adduser --system --shell  /bin/false --home /opt/akkoma akkoma

# Set the flavour environment variable to the string you got in Detecting flavour section.
# For example if the flavour is `amd64-musl` the command will be
export FLAVOUR="amd64-musl"

# Clone the release build into a temporary directory and unpack it
su akkoma -s $SHELL -lc "
curl 'https://akkoma-updates.s3-website.fr-par.scw.cloud/develop/akkoma-$FLAVOUR.zip' -o /tmp/akkoma.zip
unzip /tmp/akkoma.zip -d /tmp/
"

# Move the release to the home directory and delete temporary files
su akkoma -s $SHELL -lc "
mv /tmp/release/* /opt/akkoma
rmdir /tmp/release
rm /tmp/akkoma.zip
"
# Create uploads directory and set proper permissions (skip if planning to use a remote uploader)
# Note: It does not have to be `/var/lib/akkoma/uploads`, the config generator will ask about the upload directory later

mkdir -p /var/lib/akkoma/uploads
chown -R akkoma /var/lib/akkoma

# Create custom public files directory (custom emojis, frontend bundle overrides, robots.txt, etc.)
# Note: It does not have to be `/var/lib/akkoma/static`, the config generator will ask about the custom public files directory later
mkdir -p /var/lib/akkoma/static
chown -R akkoma /var/lib/akkoma

# Create a config directory
mkdir -p /etc/akkoma
chown -R akkoma /etc/akkoma

# Run the config generator
su akkoma -s $SHELL -lc "./bin/pleroma_ctl instance gen --output /etc/akkoma/config.exs --output-psql /tmp/setup_db.psql"

# Create the postgres database
su postgres -s $SHELL -lc "psql -f /tmp/setup_db.psql"

# Create the database schema
su akkoma -s $SHELL -lc "./bin/pleroma_ctl migrate"

# If you have installed RUM indexes uncommend and run
# su akkoma -s $SHELL -lc "./bin/pleroma_ctl migrate --migrations-path priv/repo/optional_migrations/rum_indexing/"

# Start the instance to verify that everything is working as expected
su akkoma -s $SHELL -lc "./bin/pleroma daemon"

# Wait for about 20 seconds and query the instance endpoint, if it shows your uri, name and email correctly, you are configured correctly
sleep 20 && curl http://localhost:4000/api/v1/instance

# Stop the instance
su akkoma -s $SHELL -lc "./bin/pleroma stop"
```

### Setting up nginx and getting Let's Encrypt SSL certificaties

#### Get a Let's Encrypt certificate
```sh
certbot certonly --standalone --preferred-challenges http -d yourinstance.tld
```

#### Copy Akkoma nginx configuration to the nginx folder

The location of nginx configs is dependent on the distro

=== "Alpine"
    ```
    cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/conf.d/akkoma.conf
    ```

=== "Debian/Ubuntu"
    ```
    cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/sites-available/akkoma.conf
    ln -s /etc/nginx/sites-available/akkoma.conf /etc/nginx/sites-enabled/akkoma.conf
    ```

If your distro does not have either of those you can append `include /etc/nginx/akkoma.conf` to the end of the http section in /etc/nginx/nginx.conf and
```sh
cp /opt/akkoma/installation/nginx/akkoma.nginx /etc/nginx/akkoma.conf
```

#### Edit the nginx config
```sh
# Replace example.tld with your (sub)domain
$EDITOR path-to-nginx-config

# Verify that the config is valid
nginx -t
```
#### Start nginx

=== "Alpine"
    ```
    rc-service nginx start
    ```

=== "Debian/Ubuntu"
    ```
    systemctl start nginx
    ```

At this point if you open your (sub)domain in a browser you should see a 502 error, that's because Akkoma is not started yet.

### Setting up a system service

=== "Alpine"
    ```
    # Copy the service into a proper directory
    cp /opt/akkoma/installation/init.d/akkoma /etc/init.d/akkoma

    # Start akkoma and enable it on boot
    rc-service akkoma start
    rc-update add akkoma
    ```

=== "Debian/Ubuntu"
    ```
    # Copy the service into a proper directory
    cp /opt/akkoma/installation/akkoma.service /etc/systemd/system/akkoma.service

    # Start akkoma and enable it on boot
    systemctl start akkoma
    systemctl enable akkoma
    ```

If everything worked, you should see Akkoma-FE when visiting your domain. If that didn't happen, try reviewing the installation steps, starting Akkoma in the foreground and seeing if there are any errrors.

{! support.include !}

## Post installation

### Setting up auto-renew of the Let's Encrypt certificate
```sh
# Create the directory for webroot challenges
mkdir -p /var/lib/letsencrypt

# Uncomment the webroot method
$EDITOR path-to-nginx-config

# Verify that the config is valid
nginx -t
```

=== "Alpine"
    ```
    # Restart nginx
    rc-service nginx restart

    # Start the cron daemon and make it start on boot
    rc-service crond start
    rc-update add crond

    # Ensure the webroot menthod and post hook is working
    certbot renew --cert-name yourinstance.tld --webroot -w /var/lib/letsencrypt/ --dry-run --post-hook 'rc-service nginx reload'

    # Add it to the daily cron
    echo '#!/bin/sh
    certbot renew --cert-name yourinstance.tld --webroot -w /var/lib/letsencrypt/ --post-hook "rc-service nginx reload"
    ' > /etc/periodic/daily/renew-akkoma-cert
    chmod +x /etc/periodic/daily/renew-akkoma-cert

    # If everything worked the output should contain /etc/cron.daily/renew-akkoma-cert
    run-parts --test /etc/periodic/daily
    ```

=== "Debian/Ubuntu"
    ```
    # Restart nginx
    systemctl restart nginx

    # Ensure the webroot menthod and post hook is working
    certbot renew --cert-name yourinstance.tld --webroot -w /var/lib/letsencrypt/ --dry-run --post-hook 'systemctl reload nginx'

    # Add it to the daily cron
    echo '#!/bin/sh
    certbot renew --cert-name yourinstance.tld --webroot -w /var/lib/letsencrypt/ --post-hook "systemctl reload nginx"
    ' > /etc/cron.daily/renew-akkoma-cert
    chmod +x /etc/cron.daily/renew-akkoma-cert

    # If everything worked the output should contain /etc/cron.daily/renew-akkoma-cert
    run-parts --test /etc/cron.daily
    ```

## Create your first user and set as admin
```sh
cd /opt/akkoma
su akkoma -s $SHELL -lc "./bin/pleroma_ctl user new joeuser joeuser@sld.tld --admin"
```
This will create an account withe the username of 'joeuser' with the email address of joeuser@sld.tld, and set that user's account as an admin. This will result in a link that you can paste into the browser, which logs you in and enables you to set the password.

{! installation/frontends.include !}

## Further reading

{! installation/further_reading.include !}

{! support.include !}
