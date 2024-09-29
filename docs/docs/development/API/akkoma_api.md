# Akkoma API

Request authentication (if required) and parameters work the same as for [Pleroma API](pleroma_api.md).

## `/api/v1/akkoma/preferred_frontend/available`
### Returns the available frontends which can be picked as the preferred choice
* Method: `GET`
* Authentication: not required
* Params: none
* Response: JSON
* Example response:
```json
["pleroma-fe/stable"]
```

!!! note
    There’s also a browser UI under `/akkoma/frontend`
    for interactively querying and changing this.

## `/api/v1/akkoma/preferred_frontend`
### Configures the preferred frontend of this session
* Method: `PUT`
* Authentication: not required
* Params:
    * `frontend_name`: STRING containing one of the available frontends
* Response: JSON
* Example response:
```json
{"frontend_name":"pleroma-fe/stable"}
```

!!! note
    There’s also a browser UI under `/akkoma/frontend`
    for interactively querying and changing this.

## `/api/v1/akkoma/metrics`
### Provides metrics for Prometheus to scrape
* Method: `GET`
* Authentication: required (admin:metrics)
* Params: none
* Response: text
* Example response:
```
# HELP pleroma_remote_users_total
# TYPE pleroma_remote_users_total gauge
pleroma_remote_users_total 25
# HELP pleroma_local_statuses_total
# TYPE pleroma_local_statuses_total gauge
pleroma_local_statuses_total 17
# HELP pleroma_domains_total
# TYPE pleroma_domains_total gauge
pleroma_domains_total 4
# HELP pleroma_local_users_total
# TYPE pleroma_local_users_total gauge
pleroma_local_users_total 3
...
```

## `/api/v1/akkoma/translation/languages`
### Returns available source and target languages for automated text translation
* Method: `GET`
* Authentication: required
* Params: none
* Response: JSON
* Example response:
```json
{
  "source": [
    {"code":"LV", "name":"Latvian"},
    {"code":"ZH", "name":"Chinese (traditional)"},
    {"code":"EN-US", "name":"English (American)"}
  ],
  "target": [
    {"code":"EN-GB", "name":"English (British)"},
    {"code":"JP", "name":"Japanese"}
  ]
}
```

## `/api/v1/akkoma/frontend_settings/:frontend_name`
### Lists all configuration profiles of the selected frontend for the current user
* Method: `GET`
* Authentication: required
* Params: none
* Response: JSON
* Example response:
```json
[
  {"name":"default","version":31}
]
```

## `/api/v1/akkoma/frontend_settings/:frontend_name/:profile_name`
### Returns the full selected frontend settings profile of the current user
* Method: `GET`
* Authentication: required
* Params: none
* Response: JSON
* Example response:
```json
{
  "version": 31,
  "settings": {
    "streaming": true,
    "conversationDisplay": "tree",
    ...
  }
}
```

## `/api/v1/akkoma/frontend_settings/:frontend_name/:profile_name`
### Updates the frontend settings profile
* Method: `PUT`
* Authentication: required
* Params:
    * `version`: INTEGER
    * `settings`: JSON object containing the entire new settings
* Response: JSON
* Example response:
```json
{
  "streaming": false,
  "conversationDisplay": "tree",
  ...
}
```

!!! note
    The `version` field must be increased by exactly one on each update

## `/api/v1/akkoma/frontend_settings/:frontend_name/:profile_name`
### Drops the specified frontend settings profile
* Method: `DELETE`
* Authentication: required
* Params: none
* Response: JSON
* Example response:
```json
{"deleted":"ok"}
```


## `/api/v1/timelines/bubble`
### Returns a timeline for the local and closely related instances
Works like all other Mastodon-API timeline queries with the documented
[Akkoma-specific additions and tweaks](./differences_in_mastoapi_responses.md#timelines).
