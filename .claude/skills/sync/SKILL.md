---
name: sync
description: Run `/sweep`, then run `/pipeline` only if the sweeper returned non-empty messages. Use when the operator says "/sync" or "sweep and refresh now".
---

# sync

Conditional composition of two skills:

1. **Run `/sweep`.** That skill dispatches the `outbox-sweeper` subagent in the background and notifies Lilo when the JSON summary arrives. `/sweep`'s own step 2 handles relaying any found messages to the operator — `/sync` does NOT re-implement that.
2. **On sweeper notification, gate on `messages`:**
   - **`messages` non-empty** → run `/pipeline` (which dispatches the `pipeline-syncer` subagent in the background and surfaces only errors). Don't narrate the dispatch.
   - **`messages` empty** → stop. Stay silent unless `/sweep` itself reported errors.

If the operator wants pipeline regardless of sweep results, they type `/pipeline` directly. `/sync` is the conditional path.
