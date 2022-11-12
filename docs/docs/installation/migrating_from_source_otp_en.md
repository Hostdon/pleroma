# Switching a from-source install to OTP releases

{! installation/otp_vs_from_source.include !}

In this guide we cover how you can migrate from a from source installation to one using OTP releases.

## Pre-requisites
You will be running commands as root. If you aren't root already, please elevate your priviledges by executing `sudo su`/`su`.

The system needs to have `curl` and `unzip` installed for downloading and unpacking release builds.

=== "Alpine"
    ```sh
    apk add curl unzip
    ```

=== "Debian/Ubuntu"
    ```sh
    apt install curl unzip
    ```

## Moving content out of the application directory
When using OTP releases the application directory changes with every version so it would be a bother to keep content there (and also dangerous unless `--no-rm` option is used when updating). Fortunately almost all paths in Akkoma are configurable, so it is possible to move them out of there.

Akkoma should be stopped before proceeding.

### Moving uploads/custom public files directory

```sh
# Create uploads directory and set proper permissions (skip if using a remote uploader)
# Note: It does not have to be `/var/lib/akkoma/uploads`, you can configure it to be something else later
mkdir -p /var/lib/akkoma/uploads
chown -R akkoma /var/lib/akkoma

# Create custom public files directory
# Note: It does not have to be `/var/lib/akkoma/static`, you can configure it to be something else later
mkdir -p /var/lib/akkoma/static
chown -R akkoma /var/lib/akkoma

# If you use the local uploader with default settings your uploads should be located in `~akkoma/uploads`
mv ~akkoma/uploads/* /var/lib/akkoma/uploads

# If you have created the custom public files directory with default settings it should be located in `~akkoma/instance/static`
mv ~akkoma/instance/static /var/lib/akkoma/static
```

### Moving emoji
Assuming you have all emojis in subdirectories of `priv/static/emoji` moving them can be done with
```sh
mkdir /var/lib/akkoma/static/emoji
ls -d ~akkoma/priv/static/emoji/*/ | xargs -i sh -c 'mv "{}" "/var/lib/akkoma/static/emoji/$(basename {})"'
```

But, if for some reason you have custom emojis in the root directory you should copy the whole directory instead.
```sh
mv ~akkoma/priv/static/emoji /var/lib/akkoma/static/emoji
```
and then copy custom emojis to `/var/lib/akkoma/static/emoji/custom`. 

This is needed because storing custom emojis in the root directory is deprecated, but if you just move them to `/var/lib/akkoma/static/emoji/custom` it will break emoji urls on old posts.

Note that globs have been replaced with `pack_extensions`, so if your emojis are not in png/gif you should [modify the default value](../configuration/cheatsheet.md#emoji).

### Moving the config
```sh
# Create the config directory
# The default path for Akkoma config is /etc/akkoma/config.exs
# but it can be set via PLEROMA_CONFIG_PATH environment variable
mkdir -p /etc/akkoma

# Move the config file
mv ~akkoma/config/prod.secret.exs /etc/akkoma/config.exs

# Change `use Mix.Config` at the top to `import Config`
$EDITOR /etc/akkoma/config.exs
```
## Installing the release
Before proceeding, get the flavour from [Detecting flavour](otp_en.md#detecting-flavour) section in OTP installation guide.
```sh
# Delete all files in akkoma user's directory
rm -r ~akkoma/*

# Set the flavour environment variable to the string you got in Detecting flavour section.
# For example if the flavour is `amd64-musl` the command will be
export FLAVOUR="amd64-musl"

# Clone the release build into a temporary directory and unpack it
# Replace `stable` with `unstable` if you want to run the unstable branch
su akkoma -s $SHELL -lc "
curl 'https://akkoma-updates.s3-website.fr-par.scw.cloud/stable/akkoma-$FLAVOUR.zip' -o /tmp/akkoma.zip
unzip /tmp/akkoma.zip -d /tmp/
"

# Move the release to the home directory and delete temporary files
su akkoma -s $SHELL -lc "
mv /tmp/release/* ~akkoma/
rmdir /tmp/release
rm /tmp/akkoma.zip
"

# Start the instance to verify that everything is working as expected
su akkoma -s $SHELL -lc "./bin/pleroma daemon"

# Wait for about 20 seconds and query the instance endpoint, if it shows your uri, name and email correctly, you are configured correctly
sleep 20 && curl http://localhost:4000/api/v1/instance

# Stop the instance
su akkoma -s $SHELL -lc "./bin/pleroma stop"
```

## Setting up a system service
OTP releases have different service files than from-source installs so they need to be copied over again.

**Warning:** The service files assume akkoma user's home directory is `/opt/akkoma`, please make sure all paths fit your installation.

=== "Alpine"
    ```sh
    # Copy the service into a proper directory
    cp -f ~akkoma/installation/init.d/akkoma /etc/init.d/akkoma

    # Start akkoma
    rc-service akkoma start
    ```

=== "Debian/Ubuntu"
    ```sh
    # Copy the service into a proper directory
    cp ~akkoma/installation/akkoma.service /etc/systemd/system/akkoma.service

    # Reload service files
    systemctl daemon-reload

    # Reenable akkoma to start on boot
    systemctl reenable akkoma

    # Start akkoma
    systemctl start akkoma
    ```

## Running mix tasks
Refer to [Running mix tasks](otp_en.md#running-mix-tasks) section from OTP release installation guide.
## Updating
Refer to [Updating](otp_en.md#updating) section from OTP release installation guide.

{! support.include !}
