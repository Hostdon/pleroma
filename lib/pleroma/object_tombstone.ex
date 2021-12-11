# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ObjectTombstone do
  @enforce_keys [:id, :formerType, :deleted]
  defstruct [:id, :formerType, :deleted, type: "Tombstone"]
end
