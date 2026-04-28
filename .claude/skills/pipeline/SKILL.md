---
name: pipeline
description: 60-minute Notion dashboard refresh — dispatches the `pipeline-syncer` subagent to render pipeline data, diff against the per-project sync cache + parent-page fingerprint, and fire only the Notion calls that are required. Steady state is 0 calls. The subagent returns a JSON summary; Lilo only surfaces errors to the operator. Use when the operator says "/pipeline", "refresh the dashboard", or when the recurring 60-min cron fires (`17 * * * *`).
---

# pipeline

Thin dispatcher. The real work happens in the `pipeline-syncer` subagent — Lilo only spends context if something errored.

## Step 0 — Ensure the pipeline cron is registered (idempotent)

Cron is session-only memory; it dies with the session. Run this every time `/pipeline` is invoked so a fresh session or `--continue` self-heals.

1. `CronList`. Look for a recurring job whose prompt is exactly `/pipeline` on schedule `17 * * * *`.
2. If found, skip step 0.
3. If not found, `CronCreate`:
   - `cron`: `17 * * * *`
   - `recurring`: true
   - `prompt`: `/pipeline`

Stay silent unless something failed.

## Step 1 — Dispatch the subagent

```
Agent({
  subagent_type: "pipeline-syncer",
  description: "Hourly Notion dashboard refresh",
  prompt: "Refresh the pipeline dashboard. Return the JSON summary."
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
- **`errors` non-empty:** surface a one-line summary to the operator regardless of cron vs manual. Broken telemetry should not be silent.

## Manual invocation

When the operator runs `/pipeline` directly (rare — usually they let the cron do the work), behave the same way: dispatch the subagent, surface only errors. If they want to see what was synced, they can ask.
