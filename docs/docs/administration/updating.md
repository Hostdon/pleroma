# Updating your instance

You should **always check the [release notes/changelog](https://akkoma.dev/AkkomaGang/akkoma/src/branch/develop/CHANGELOG.md)** in case there are config deprecations, special update steps, etc.

Besides that, doing the following is generally enough:

## For OTP installations

```sh
# Download the new release
su akkoma -s $SHELL -lc "./bin/pleroma_ctl update" 

# Migrate the database, you are advised to stop the instance before doing that
su akkoma -s $SHELL -lc "./bin/pleroma_ctl migrate"
```

If you selected an alternate flavour on installation, 
you _may_ need to specify `--flavour`, in the same way as 
[when installing](../../installation/otp_en#detecting-flavour).

## For from source installations (using git)

1. Go to the working directory of Akkoma (default is `/opt/akkoma`)
2. Run `git pull` [^1]. This pulls the latest changes from upstream.
3. Run `mix deps.get` [^1]. This pulls in any new dependencies.
4. Stop the Akkoma service.
5. Run `mix ecto.migrate` [^1] [^2]. This task performs database migrations, if there were any.
6. Start the Akkoma service.

[^1]: Depending on which install guide you followed (for example on Debian/Ubuntu), you want to run `git` and `mix` tasks as `akkoma` user by adding `sudo -Hu akkoma` before the command.
[^2]: Prefix with `MIX_ENV=prod` to run it using the production config file.
