# Managing frontends

`mix pleroma.frontend install <frontend> [--ref <ref>] [--file <file>] [--build-url <build-url>] [--path <path>] [--build-dir <build-dir>]`

Frontend can be installed either from local zip file, or automatically downloaded from the web.

You can give all the options directly on the command like, but missing information will be filled out by looking at the data configured under `frontends.available` in the config files.

Currently known `<frontend>` values are:
- [admin-fe](https://git.pleroma.social/pleroma/admin-fe)
- [kenoma](http://git.pleroma.social/lambadalambda/kenoma)
- [pleroma-fe](http://git.pleroma.social/pleroma/pleroma-fe)
- [fedi-fe](https://git.pleroma.social/pleroma/fedi-fe)
- [soapbox-fe](https://gitlab.com/soapbox-pub/soapbox-fe)

You can still install frontends that are not configured, see below.

## Example installations for a known frontend

For a frontend configured under the `available` key, it's enough to install it by name.

```sh tab="OTP"
./bin/pleroma_ctl frontend install pleroma
```

```sh tab="From Source"
mix pleroma.frontend install pleroma
```

This will download the latest build for the the pre-configured `ref` and install it. It can then be configured as the one of the served frontends in the config file (see `primary` or `admin`).

You can override any of the details. To install a pleroma build from a different url, you could do this:

```sh tab="OPT"
./bin/pleroma_ctl frontend install pleroma --ref 2hu_edition --build-url https://example.org/raymoo.zip
```

```sh tab="From Source"
mix pleroma.frontend install pleroma --ref 2hu_edition --build-url https://example.org/raymoo.zip
```

Similarly, you can also install from a local zip file.

```sh tab="OTP"
./bin/pleroma_ctl frontend install pleroma --ref mybuild --file ~/Downloads/doomfe.zip
```

```sh tab="From Source"
mix pleroma.frontend install pleroma --ref mybuild --file ~/Downloads/doomfe.zip
```

The resulting frontend will always be installed into a folder of this template: `${instance_static}/frontends/${name}/${ref}`

Careful: This folder will be completely replaced on installation

## Example installation for an unknown frontend

The installation process is the same, but you will have to give all the needed options on the commond line. For example:

```sh tab="OTP"
./bin/pleroma_ctl frontend install gensokyo --ref master --build-url https://gensokyo.2hu/builds/marisa.zip
```

```sh tab="From Source"
mix pleroma.frontend install gensokyo --ref master --build-url https://gensokyo.2hu/builds/marisa.zip
```

If you don't have a zip file but just want to install a frontend from a local path, you can simply copy the files over a folder of this template: `${instance_static}/frontends/${name}/${ref}`

