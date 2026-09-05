# Federation

## Supported federation protocols and standards

- [ActivityPub](https://www.w3.org/TR/activitypub/) (Server-to-Server)
- [WebFinger](https://webfinger.net/)
- [Http Signatures](https://datatracker.ietf.org/doc/html/draft-cavage-http-signatures)
- [NodeInfo](https://nodeinfo.diaspora.software/)

## Supported FEPs

- [FEP-67ff: FEDERATION](https://codeberg.org/fediverse/fep/src/branch/main/fep/67ff/fep-67ff.md)
- [FEP-2c59: Discovery of a Webfinger address from an ActivityPub actor](https://codeberg.org/fediverse/fep/src/branch/main/fep/2c59/fep-2c59.md)
- [FEP-dc88: Formatting Mathematics](https://codeberg.org/fediverse/fep/src/branch/main/fep/dc88/fep-dc88.md)
- [FEP-f1d5: NodeInfo in Fediverse Software](https://codeberg.org/fediverse/fep/src/branch/main/fep/f1d5/fep-f1d5.md)
- [FEP-fffd: Proxy Objects](https://codeberg.org/fediverse/fep/src/branch/main/fep/fffd/fep-fffd.md)
- [FEP-c16b: Formatting MFM functions](https://codeberg.org/fediverse/fep/src/branch/main/fep/c16b/fep-c16b.md)

## ActivityPub

Akkoma mostly follows the server-to-server parts of the ActivityPub standard,
but implements quirks for Mastodon compatibility as well as Mastodon-specific
and custom extensions.

See our documentation and Mastodon’s federation information
linked further below for details on these quirks and extensions.

Akkoma does not perform JSON-LD processing.

### Required extensions

#### HTTP Signatures
All AP S2S POST requests to Akkoma instances MUST be signed.
Depending on instance configuration the same may be true for GET requests.

### FEP-c16b: Formatting MFM functions

We set the optional extension term `htmlMfm: true` when using content type "text/x.misskeymarkdown".
Incoming messages containing `htmlMfm: true` will not have their content re-parsed.

## WebFinger

Akkoma requires WebFinger implmentations to respond to queries about a given user both when
`acct:user@domain` or the canonical ActivityPub id of the actor is passed as the `resource`.

Akkoma strongly encourages ActivityPub implementations to include
a FEP-2c59-compliant WebFinger backlink in their actor documents.

Without FEP-2c59 and if different domains are used for ActivityPub and the Webfinger subject,
Akkoma relies on either the presence of an host-meta LRDD template on the ActivityPub domain
or a working WebFinger endpoint on the ActivityPub domain. Additionally all WebFinger endpoints
related to the ActivityPub and canonical WebFinger domain SHOULD also respond to queries about
an alternative acct URI constructed with the WebFinger domain passed as the resource.  
Without FEP-2c59 Akkoma may not become aware of changes to the
preferred WebFinger `subject` domain for already discovered users.

## Nodeinfo

Akkoma provides many additional entries in its nodeinfo response,
see the documentation linked below for details.

## Additional documentation

- [Akkoma’s ActivityPub extensions](https://docs.akkoma.dev/develop/development/ap_extensions/)
- [Akkoma’s nodeinfo extensions](https://docs.akkoma.dev/develop/development/nodeinfo_extensions/)
- [Mastodon’s federation requirements](https://github.com/mastodon/mastodon/blob/main/FEDERATION.md)
