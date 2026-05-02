---
name: pipeline
description: Notion dashboard refresh — dispatches the `pipeline-syncer` subagent to render pipeline data, diff against the per-project sync cache + parent-page fingerprint, and fire only the Notion calls that are required. Steady state is 0 calls. The subagent returns a JSON summary; Lilo only surfaces errors to the operator. Use when the operator says "/pipeline" or "refresh the dashboard".
---

# pipeline

Thin dispatcher. The real work happens in the `pipeline-syncer` subagent — Lilo only spends context if something errored.

## Step 1 — Dispatch the subagent in the background

Always dispatch with `run_in_background: true` so the call does not block Lilo's main loop. You will be notified when the subagent completes, and you handle Step 2 then.

```
Agent({
  subagent_type: "pipeline-syncer",
  description: "Notion dashboard refresh",
  prompt: "Refresh the pipeline dashboard. Return the JSON summary.",
  run_in_background: true
})
```

The subagent runs `render-pipeline.sh`, reads the cache, computes diffs, dispatches only the required Notion calls in parallel, and persists the cache. Returns:

```json
{
  "calls_made": <int>,
  "projects_synced": [{name, props_updated, body_updated, created}, ...],
  "parent_synced": <bool>,
  "errors": [...]
}
```

## Step 2 — Surface only what matters

- **`errors` empty:** stay silent. Even if `calls_made > 0`, the dashboard refresh is plumbing — the operator doesn't need a play-by-play.
- **`errors` non-empty:** surface a one-line summary to the operator regardless of caller. Broken telemetry should not be silent.
