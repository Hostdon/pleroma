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
      "generator"
    ]
  )

  const(static_only_files,
    do:
      ~w(index.html robots.txt static static-fe finmoji emoji packs sounds images instance embed sw.js sw-pleroma.js favicon.png schemas doc)
  )

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
