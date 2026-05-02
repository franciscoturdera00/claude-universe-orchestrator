---
name: sweep
description: Outbox sweep — dispatches the `outbox-sweeper` subagent to find new PM messages across every sibling project, archive them, and roll up agent feedback. The subagent returns a JSON summary; Lilo only relays to the operator if anything was found. Use when the operator says "/sweep" or "sweep now".
---

# sweep

Thin dispatcher. The real work happens in the `outbox-sweeper` subagent — Lilo only spends context when the sweep finds something.

## Step 1 — Dispatch the sweeper in the background

Always dispatch with `run_in_background: true` so the cron tick (or manual fire) does not block Lilo's main loop. You will be notified when the subagent completes, and you handle Step 2 then.

```
Agent({
  subagent_type: "outbox-sweeper",
  description: "Outbox sweep",
  prompt: "Sweep all sibling outboxes. Return the JSON summary.",
  run_in_background: true
})
```

The subagent does all the filesystem work, archives to `processed/`, appends `done`-message ratings to `agent-feedback.jsonl`, and runs `aggregate-feedback.sh` if any `done` was processed. Returns:

```json
{
  "messages": [{path_original, path_archived, content}, ...],
  "feedback_aggregation": {flagged, summary} | null,
  "errors": [...]
}
```

## Step 2 — Surface only what matters

- **`messages` empty AND `errors` empty:** stay completely silent. This is the common case (no operator-visible output).
- **`messages` non-empty:** route each per the routing table in `team-ops` SKILL section 2 (blocker/high → immediate; status/low → batch; etc.). Lead with `summary`, include `project:` as context, quote `detail` verbatim. If the operator is at the terminal, reply terse there; do not dual-post to Telegram.
- **`feedback_aggregation.flagged_count > 0`:** for each flagged agent, read `templates/team/.claude/agent-registry/<agent>.md`, eyeball the adequate-notes themes, decide whether to refine the spec. Tell the operator what changed (or that you looked and nothing needed action).
- **`errors` non-empty:** surface briefly to the operator regardless of cron vs manual — broken telemetry should not be silent.

