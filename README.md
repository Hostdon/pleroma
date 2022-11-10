## akkoma

*a smallish microblogging platform, aka the cooler pleroma*

![English OK](https://img.shields.io/badge/English-OK-blueviolet) ![日本語OK](https://img.shields.io/badge/%E6%97%A5%E6%9C%AC%E8%AA%9E-OK-blueviolet)

## About 

This is a fork of Pleroma, which is a microblogging server software that can federate (= exchange messages with) other servers that support ActivityPub. What that means is that you can host a server for yourself or your friends and stay in control of your online identity, but still exchange messages with people on larger servers. Akkoma will federate with all servers that implement ActivityPub, like Friendica, GNU Social, Hubzilla, Mastodon, Misskey, Peertube, and Pixelfed.

Akkoma is written in Elixir and uses PostgreSQL for data storage.

For clients it supports the [Mastodon client API](https://docs.joinmastodon.org/api/guidelines/) with Pleroma extensions (see the API section on <https://docs.akkoma.dev/stable/>).

- [Client Applications for Akkoma](https://docs.akkoma.dev/stable/clients/)

## Differences with Pleroma

Akkoma is a faster-paced fork, it has a varied and potentially experimental feature set tailored specifically to the corner of the fediverse inhabited by the project
creator and contributors.

This should not be considered a one-for-one match with pleroma; it is more opinionated in many ways, and has a smaller community (which is good or
bad depending on your view)

For example, Akkoma has:
- Custom Emoji reactions (compatible with misskey)
- Misskey-flavoured markdown support
- Elasticsearch and Meilisearch support for search
- Mastodon frontend (Glitch-Soc and Fedibird flavours) support
- Automatic post translation via DeepL or LibreTranslate
- A multitude of heavy modifications to the Pleroma Frontend (Pleroma-FE)
- The "bubble" concept, in which instance administrators can choose closely-related instances to make a "community of communities", so to say

And takes a more opinionated stance on issues like Domain blocks, which are enforced far more on Akkoma.

Take a look at the Changelog if you want a full list of recent changes, everything since 3.0 has been Akkoma.

## Installation

### OTP releases (Recommended)
If you are running Linux (glibc or musl) on x86, the recommended way to install Akkoma is by using OTP releases. OTP releases are as close as you can get to binary releases with Erlang/Elixir. The release is self-contained, and provides everything needed to boot it. The installation instructions are available [here](https://docs.akkoma.dev/stable/installation/otp_en/).

### From Source
If your platform is not supported, or you just want to be able to edit the source code easily, you may install Akkoma from source.

- [Alpine Linux](https://docs.akkoma.dev/stable/installation/alpine_linux_en/)
- [Arch Linux](https://docs.akkoma.dev/stable/installation/arch_linux_en/)
- [Debian-based](https://docs.akkoma.dev/stable/installation/debian_based_en/)
- [Debian-based (jp)](https://docs.akkoma.dev/stable/installation/debian_based_jp/)
- [FreeBSD](https://docs.akkoma.dev/stable/installation/freebsd_en/)
- [Gentoo Linux](https://docs.akkoma.dev/stable/installation/gentoo_en/)
- [NetBSD](https://docs.akkoma.dev/stable/installation/netbsd_en/)
- [OpenBSD](https://docs.akkoma.dev/stable/installation/openbsd_en/)
- [OpenBSD (fi)](https://docs.akkoma.dev/stable/installation/openbsd_fi/)

### Docker
While we don’t provide docker files, other people have written very good ones. Take a look at <https://github.com/angristan/docker-pleroma> or <https://glitch.sh/sn0w/pleroma-docker>.

### Compilation Troubleshooting
If you ever encounter compilation issues during the updating of Akkoma, you can try these commands and see if they fix things:

- `mix deps.clean --all`
- `mix local.rebar`
- `mix local.hex`
- `rm -r _build`

## Documentation
- https://docs.akkoma.dev/stable
