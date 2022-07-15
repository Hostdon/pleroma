**Note:** Akkoma documentation is still being updated, so you may still see references to Pleroma in many places.

# Introduction to Akkoma
## What is Akkoma?
Akkoma is a federated social networking platform, compatible with Mastodon and other ActivityPub implementations. It is free software licensed under the AGPLv3.
It actually consists of two components: a backend, named simply Akkoma, and a user-facing frontend, named Pleroma-FE. It also includes the Mastodon frontend, if that's your thing.
It's part of what we call the fediverse, a federated network of instances which speak common protocols and can communicate with each other.
One account on an instance is enough to talk to the entire fediverse!

## How can I use it?

Akkoma instances are already widely deployed, a list can be found at <https://the-federation.info/pleroma> and <https://fediverse.network/pleroma>.

If you don't feel like joining an existing instance, but instead prefer to deploy your own instance, that's easy too!
Installation instructions can be found in the installation section of these docs.

## I got an account, now what?
Great! Now you can explore the fediverse! Open the login page for your Akkoma instance (e.g. <https://pleroma.soykaf.com>) and login with your username and password. (If you don't have an account yet, click on Register)

### Pleroma-FE
The default front-end used by Akkoma is Pleroma-FE. You can find more information on what it is and how to use it in the [Introduction to Pleroma-FE](https://docs-fe.akkoma.dev/stable/).

### Mastodon interface
If the Pleroma-FE interface isn't your thing, or you're just trying something new but you want to keep using the familiar Mastodon interface, we got that too!
Just add a "/web" after your instance url (e.g. <https://pleroma.soykaf.com/web>) and you'll end on the Mastodon web interface, but with a Akkoma backend! MAGIC!
The Mastodon interface is from the Glitch-soc fork. For more information on the Mastodon interface you can check the [Mastodon](https://docs.joinmastodon.org/) and [Glitch-soc](https://glitch-soc.github.io/docs/) documentation.

Remember, what you see is only the frontend part of Mastodon, the backend is still Akkoma.
