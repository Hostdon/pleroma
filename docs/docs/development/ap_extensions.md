# AP Extensions
## Actor endpoints

The following endpoints are additionally present into our actors.

- `oauthRegistrationEndpoint` (`http://litepub.social/ns#oauthRegistrationEndpoint`)
- `uploadMedia` (`https://www.w3.org/ns/activitystreams#uploadMedia`)

### oauthRegistrationEndpoint

Points to MastodonAPI `/api/v1/apps` for now.

See <https://docs.joinmastodon.org/methods/apps/>

### uploadMedia

Inspired by <https://www.w3.org/wiki/SocialCG/ActivityPub/MediaUpload>, it is part of the ActivityStreams namespace because it used to be part of the ActivityPub specification and got removed from it.

Content-Type: multipart/form-data

Parameters:
- (required) `file`: The file being uploaded
- (optionnal) `description`: A plain-text description of the media, for accessibility purposes.

Response: HTTP 201 Created with the object into the body, no `Location` header provided as it doesn't have an `id`

The object given in the reponse should then be inserted into an Object's `attachment` field.

