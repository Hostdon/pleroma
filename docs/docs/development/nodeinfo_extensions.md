# Nodeinfo Extensions

Akkoma currently implements version 2.0 and 2.1 of nodeinfo spec,
but provides the following additional fields.

## metadata

The spec leaves the content of `metadata` up to implementations
and indeed Akkoma adds many fields here apart from the commonly
found `nodeName` and `nodeDescription` fields.

### accountActivationRequired
Whether or not users need to confirm their email before completing registration.
*(boolean)*

!!! note
    Not to be confused with account approval, where each registration needs to
    be manually approved by an admin. Account approval has no nodeinfo entry.

### features

Array of strings denoting supported server features. E.g. a server supporting
quote posts should include a `"quote_posting"` entry here.

A non-exhaustive list of possible features:
- `polls`
- `quote_posting`
- `editing`
- `bubble_timeline`
- `pleroma_emoji_reactions` *(Unicode emoji)*
- `custom_emoji_reactions`
- `akkoma_api`
- `akkoma:machine_translation`
- `mastodon_api`
- `pleroma_api`

### federatedTimelineAvailable
Whether or not the “federated timeline”, i.e. a timeline containing posts from
the entire known network, is made available.
*(boolean)*

### federation
This section is optional and can contain various custom keys describing federation policies.
The following are required to be presented:
- `enabled` *(boolean)* whether the server federates at all

A non-exhaustive list of optional keys:
- `exclusions` *(boolean)* whether some federation policies are withheld
- `mrf_simple` *(object)* describes how the Simple MRF policy is configured

### fieldsLimits
A JSON object documenting restriction for user account info fields.
All properties are integers.

- `maxFields` maximum number of account info fields local users can create
- `maxRemoteFields` maximum number of account info fields remote users can have
   before the user gets rejected or fields truncated
- `nameLength` maximum length of a field’s name
- `valueLength` maximum length of a field’s value

### invitesEnabled
Whether or not signing up via invite codes is possible.
*(boolean)*

### localBubbleInstances
Array of domains (as strings) of other instances chosen
by the admin which are shown in the bubble timeline.

### mailerEnabled
Whether or not the instance can send out emails.
*(boolean)*

### nodeDescription
Human-friendly description of this instance
*(string)*

### nodeName
Human-friendly name of this instance
*(string)*

### pollLimits
JSON object containing limits for polls created by local users.
All values are integers.
- `max_options` maximum number of poll options
- `max_option_chars` maximum characters per poll option
- `min_expiration` minimum time in seconds a poll must be open for
- `max_expiration` maximum time a poll is allowed to be open for

### postFormats
Array of strings containing media types for supported post source formats.
A non-exhaustive list of possible values:
- `text/plain`
- `text/markdown`
- `text/bbcode`
- `text/x.misskeymarkdown`

### private
Whether or not unauthenticated API access is permitted.
*(boolean)*

### privilegedStaff
Whether or not moderators are trusted to perform some
additional tasks like e.g. issuing password reset emails.

### publicTimelineVisibility
JSON object containing boolean-valued keys reporting
if a given timeline can be viewed without login.
- `local`
- `federated`
- `bubble`

### restrictedNicknames
Array of strings listing nicknames forbidden to be used during signup.

### skipThreadContainment
Whether broken threads are filtered out
*(boolean)*

### staffAccounts
Array containing ActivityPub IDs of local accounts
with some form of elevated privilege on the instance.

### suggestions
JSON object containing info on whether the interaction-based
Mastodon `/api/v1/suggestions` feature is enabled and optionally
additional implementation-defined fields with more details
on e.g. how suggested users are selected.

!!! note
    This has no relation to the newer /api/v2/suggestions API
    which also (or exclusively) contains staff-curated entries.

- `enabled` *(boolean)* whether or not user recommendations are enabled

### uploadLimits
JSON object documenting various upload-related size limits.
All values are integers and in bytes.
- `avatar` maximum size of uploaded user avatars
- `banner` maximum size of uploaded user profile banners
- `background` maximum size of uploaded user profile backgrounds
- `general` maximum size for all other kinds of uploads
