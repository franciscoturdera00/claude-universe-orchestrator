---
name: check-outbox
description: Manual umbrella that runs the full sweep + pipeline refresh in sequence and ensures both recurring crons are registered for this session. Most of the time the operator does NOT invoke this — the cron-fired `/sweep` (every 10 min) and `/pipeline` (every 60 min) handle it autonomously, dispatching subagents so Lilo's context stays clean. Use this only when the operator says "/check-outbox", "sweep and refresh now", or on session start to bootstrap both crons.
---

# check-outbox

Lilo's coordination loop runs as two specialized cron skills, each dispatching a dedicated subagent so the orchestrator's main context stays clean:

- `/sweep` — outbox sweep + relay, every 10 min via the `outbox-sweeper` subagent
- `/pipeline` — Notion dashboard refresh, every 60 min via the `pipeline-syncer` subagent

`/check-outbox` is the **manual umbrella** that runs both right now and ensures both crons are registered. It does not introduce a third cron of its own.

## Step 0 — Bootstrap both crons (idempotent)

Crons are session-only memory; they die with the session. Run this every invocation so a fresh session or `--continue` self-heals.

1. `CronList`. You're looking for two recurring jobs:
   - prompt `/sweep` on schedule `2,12,22,32,42,52 * * * *`
   - prompt `/pipeline` on schedule `17 * * * *`
2. **Migrate legacy:** if you see a recurring `/check-outbox` job (the old single cron), delete it via `CronDelete` — it has been split.
3. For each missing cron, `CronCreate`:
   - sweep: `cron: "2,12,22,32,42,52 * * * *"`, `recurring: true`, `prompt: "/sweep"`
   - pipeline: `cron: "17 * * * *"`, `recurring: true`, `prompt: "/pipeline"`

Stay silent unless something failed.

If the operator has previously told you to stop polling, do NOT register either cron. When they ask you to resume, re-bootstrap by invoking this skill once.

## Step 1 — Run /sweep now

Invoke the `sweep` skill so any queued PM messages get relayed immediately. (The skill's own step 0 will register its cron if missing — that's redundant after step 0 above but idempotent and harmless.)

## Step 2 — Run /pipeline now

Invoke the `pipeline` skill so the dashboard reflects current state.

## Output

- **Operator-fired and nothing new:** `Nothing new. Pipeline refreshed.`
- **Has outbox messages:** terse summary per relayed message (handled inside `/sweep`), then the pipeline-refresh status.
- **Errors:** surface briefly per the same rules in `/sweep` and `/pipeline`.
