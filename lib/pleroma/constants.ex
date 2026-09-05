# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Constants do
  use Const

  const(as_public, do: "https://www.w3.org/ns/activitystreams#Public")

  const(object_internal_fields,
    do: [
      "reactions",
      "reaction_count",
      "likes",
      "like_count",
      "announcements",
      "announcement_count",
      "emoji",
      "context_id",
      "deleted_activity_id",
      "pleroma_internal",
      "generator",
      "voters"
    ]
  )

  const(static_only_files,
    do:
      ~w(index.html robots.txt static static-fe finmoji emoji packs sounds images instance embed sw.js sw-pleroma.js favicon.png schemas doc)
  )

  # XXX: should we start allowing addressing/visibility to change via updates,
  # we must also make sure to sync this new data to the Create activity and its recipients field
  # as well as adding more safeguards to inlined statuses in Notifications, since access to
  # a previously accessible and notified-about post may be lost.
  const(status_updatable_fields,
    do: [
      "source",
      "tag",
      "updated",
      "emoji",
      "content",
      "summary",
      "sensitive",
      "attachment",
      "generator",
      "contentMap"
    ]
  )

  const(updatable_object_types,
    do: [
      "Note",
      "Question",
      "Audio",
      "Video",
      "Event",
      "Article",
      "Page"
    ]
  )

  const(actor_types,
    do: [
      "Application",
      "Group",
      "Organization",
      "Person",
      "Service"
    ]
  )

  # Internally used as top-level types for media attachments and user images
  const(attachment_types, do: ["Document", "Image"])
end
