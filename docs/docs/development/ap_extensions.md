# AP Extensions
## Actor endpoints

The following endpoints are additionally present into our actors.

- `oauthRegistrationEndpoint` (`http://litepub.social/ns#oauthRegistrationEndpoint`)

### oauthRegistrationEndpoint

Points to MastodonAPI `/api/v1/apps` for now.

See <https://docs.joinmastodon.org/methods/apps/>

## Emoji reactions

Emoji reactions are implemented as a new activity type `EmojiReact`.
A single user is allowed to react multiple times with different emoji to the
same post. However, they may only react at most once with the same emoji.
Repeated reaction from the same user with the same emoji are to be ignored.
Emoji reactions are also distinct from `Like` activities and a user may both
`Like` and react to a post.

!!! note
    Misskey also supports emoji reactions, but the implementations differs.
    It equates likes and reactions and only allows a single reaction per post.

The emoji is placed in the `content` field of the activity
and the `object` property points to the note reacting to.

Emoji can either be any Unicode emoji sequence or a custom emoji.
The latter must place their shortcode, including enclosing colons,
into `content` and put the emoji object inside the `tag` property.
The `tag` property MAY be omitted for Unicode emoji.

An example reaction with a Unicode emoji:
```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://example.org/schemas/litepub-0.1.jsonld",
    {
      "@language": "und"
    }
  ],
  "type": "EmojiReact",
  "id": "https://example.org/activities/23143872a0346141",
  "actor": "https://example.org/users/akko",
  "nickname": "akko",
  "to": ["https://remote.example/users/diana", "https://example.org/users/akko/followers"],
  "cc": ["https://www.w3.org/ns/activitystreams#Public"],
  "content": "🧡",
  "object": "https://remote.example/objects/9f0e93499d8314a9"
}
```

An example reaction with a custom emoji:
```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://example.org/schemas/litepub-0.1.jsonld",
    {
      "@language": "und"
    }
  ],
  "type": "EmojiReact",
  "id": "https://example.org/activities/d75586dec0541650",
  "actor": "https://example.org/users/akko",
  "nickname": "akko",
  "to": ["https://remote.example/users/diana", "https://example.org/users/akko/followers"],
  "cc": ["https://www.w3.org/ns/activitystreams#Public"],
  "content": ":mouse:",
  "object": "https://remote.example/objects/9f0e93499d8314a9",
  "tag": [{
    "type": "Emoji",
    "id": null,
    "name": "mouse",
    "icon": {
      "type": "Image",
      "url": "https://example.org/emoji/mouse/mouse.png"
    }
  }]
}
```

!!! note
    Although an emoji reaction can only contain a single emoji,
    for compatibility with older versions of Pleroma and Akkoma,
    it is recommended to wrap the emoji object in a single-element array.

When reacting with a remote custom emoji do not include the remote domain in `content`’s shortcode
*(unlike in our REST API which needs the domain)*:
```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://example.org/schemas/litepub-0.1.jsonld",
    {
      "@language": "und"
    }
  ],
  "type": "EmojiReact",
  "id": "https://example.org/activities/7993dcae98d8d5ec",
  "actor": "https://example.org/users/akko",
  "nickname": "akko",
  "to": ["https://remote.example/users/diana", "https://example.org/users/akko/followers"],
  "cc": ["https://www.w3.org/ns/activitystreams#Public"],
  "content": ":hug:",
  "object": "https://remote.example/objects/9f0e93499d8314a9",
  "tag": [{
    "type": "Emoji",
    "id": "https://other.example/emojis/hug",
    "name": "hug",
    "icon": {
      "type": "Image",
      "url": "https://other.example/files/b71cea432b3fad67.webp"
    }
  }]
}
```

Emoji reactions can be retracted using a standard `Undo` activity:
```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "http://example.org/schemas/litepub-0.1.jsonld",
    {
      "@language": "und"
    }
  ],
  "type": "Undo",
  "id": "http://example.org/activities/4685792e-efb6-4309-b508-ae4f355dd695",
  "actor": "https://example.org/users/akko",
  "to": ["https://remote.example/users/diana", "https://example.org/users/akko/followers"],
  "cc": ["https://www.w3.org/ns/activitystreams#Public"],
  "object": "https://example.org/activities/23143872a0346141"
}
```

## User profile backgrounds

Akkoma federates user profile backgrounds the same way as Sharkey.

An actors ActivityPub representation contains an additional
`backgroundUrl` property containing an `Image` object. This property
belongs to the `"sharkey": "https://joinsharkey.org/ns#"` namespace.

## Quote Posts

Akkoma allows referencing a single other note as a quote,
which will be prominently displayed in the interface.

The quoted post is referenced by its ActivityPub id in the `quoteUri` property.

!!! note
    Old Misskey only understood and modern Misskey still prefers
    the `_misskey_quote` property for this. Similar some other older
    software used `quoteUrl` or `quoteURL`.  
    All current implementations with quote support understand `quoteUri`.

Example:
```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://example.org/schemas/litepub-0.1.jsonld",
    {
      "@language": "und"
    }
  ],
  "type": "Note",
  "id": "https://example.org/activities/85717e587f95d5c0",
  "actor": "https://example.org/users/akko",
  "to": ["https://remote.example/users/diana", "https://example.org/users/akko/followers"],
  "cc": ["https://www.w3.org/ns/activitystreams#Public"],
  "context": "https://example.org/contexts/1",
  "content": "Look at that!",
  "quoteUri": "http://remote.example/status/85717e587f95d5c0",
  "contentMap": {
    "en": "Look at that!"
  },
  "source": {
    "content": "Look at that!",
    "mediaType": "text/plain"
  },
  "published": "2024-04-06T23:40:28Z",
  "updated": "2024-04-06T23:40:28Z",
  "attachemnt": [],
  "tag": []
}
```

## Threads

Akkoma assigns all posts of the same thread the same `context`. This is a
standard ActivityPub property but its meaning is left vague. Akkoma will
always treat posts with identical `context` as part of the same thread.

`context` must not be assumed to hold any meaning or be dereferencable.

Incoming posts without `context` will be assigned a new context.

!!! note
    Mastodon uses the non-standard `conversation` property for the same purpose
    *(named after an older OStatus property)*. For incoming posts without
    `context` but with `converstions` Akkoma will use the value from
    `conversations` to fill in `context`.
    For outgoing posts Akkoma will duplicate the context into `conversation`.

## Post Source

Unlike Mastodon, Akkoma supports drafting posts in multiple source formats
besides plaintext, like Markdown or MFM. The original input is preserved
in the standard ActivityPub `source` property *(not supported by Mastodon)*.
Still, `content` will always be present and contain the prerendered HTML form.

Supported `mediaType` include:
- `text/plain`
- `text/markdown`
- `text/bbcode`
- `text/x.misskeymarkdown`

## Post Language

!!! note
    This is also supported in and compatible with Mastodon, but since
    joinmastodon.org doesn’t document it yet it is included here.
    [GoToSocial](https://docs.gotosocial.org/en/latest/federation/federating_with_gotosocial/#content-contentmap-and-language)
    has a more refined version of this which can correctly deal with multiple language entries.

A post can indicate its language by including a `contentMap` object
which contains a sub key named after the language’s ISO 639-1 code
and it’s content identical to the post’s `content` field.

Currently Akkoma, just like Mastodon, only properly supports a single language entry,
in case of multiple entries a random language will be picked.  
Furthermore, Akkoma currently only reads the `content` field
and never the value from `contentMap`.

## Local post scope

Post using this scope will never federate to other servers
but for the sake of completeness it is listed here.

In addition to the usual scopes *(public, unlisted, followers-only, direct)*
Akkoma supports an “unlisted” post scope. Such posts will not federate to
other instances and only be shown to logged-in users on the same instance.
It is included into the local timeline.  
This may be useful to discuss or announce instance-specific policies and topics.

A post is addressed to the local scope by including `<base url of instance>/#Public`
in its `to` field. E.g. if the instance is on `https://example.org` it would use
`https://example.org/#Public`.

An implementation creating a new post MUST NOT address both the local and
general public scope `as:Public` at the same time. A post addressing the local
scope MUST NOT be sent to other instances or be possible to fetch by other
instances regardless of potential other listed addressees.

When receiving a remote post addressing both the public scope and what appears
to be a local-scope identifier, the post SHOULD be treated without assigning any
special meaning to the potential local-scope identifier.

!!! note
    Misskey-derivatives have a similar concept of non-federated posts,
    however those are also shown publicly on the local web interface
    and are thus visible to non-members.

## List post scope

Messages originally addressed to a custom list will contain
a `listMessage` field with an unresolvable pseudo ActivityPub id.

# Deprecated and Removed Extensions

The following extensions were used in the past but have been dropped.
Documentation is retained here as a reference and since old objects might
still contains related fields.

## Actor endpoints

The following endpoints used to be present:

- `uploadMedia` (`https://www.w3.org/ns/activitystreams#uploadMedia`)

### uploadMedia

Inspired by <https://www.w3.org/wiki/SocialCG/ActivityPub/MediaUpload>, it is part of the ActivityStreams namespace because it used to be part of the ActivityPub specification and got removed from it.

Content-Type: multipart/form-data

Parameters:
- (required) `file`: The file being uploaded
- (optional) `description`: A plain-text description of the media, for accessibility purposes.

Response: HTTP 201 Created with the object into the body, no `Location` header provided as it doesn't have an `id`

The object given in the response should then be inserted into an Object's `attachment` field.
