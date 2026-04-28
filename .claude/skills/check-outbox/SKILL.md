---
name: check-outbox
description: Bootstrap the recurring outbox-sweep cron (idempotent) and sweep all sibling project outboxes for unprocessed PM messages, routing each via team-ops. Thin wrapper — team-ops owns schema validation, type/priority routing, archive, and the registry-refinement aggregation for `done` messages. Use when the operator says "sweep", "check outbox", "/check-outbox", on session start, after `--continue`, or when the recurring cron fires.
---

# check-outbox

Two responsibilities, in order: (1) ensure the recurring sweep cron is registered for this session, then (2) do the sweep. Both are idempotent — safe to run anytime, including after `--continue`.

## Step 0 — Ensure cron is registered (idempotent)

The cron is session-only memory; it dies with the session. Run this every time `/check-outbox` is invoked so a fresh session or `--continue` self-heals.

1. `CronList`. Look for a recurring job whose prompt is exactly `/check-outbox` on schedule `7,37 * * * *`.
2. If found, skip step 0.
3. If not found, `CronCreate`:
   - `cron`: `7,37 * * * *`
   - `recurring`: true
   - `durable`: true (note: build writes session-only regardless)
   - `prompt`: `/check-outbox`

Stay silent about this step unless something failed. The operator does not need a "cron registered" pat-on-the-back every sweep.

If the operator has previously told you to stop polling, do NOT register. When they ask you to resume, the next `/check-outbox` will re-bootstrap.

## Step 1 — Sweep

Sweep `../*/.lilo-outbox/*.json` (excluding this orchestrator repo and any `processed/` subdirs) for unprocessed PM messages.

1. Find unprocessed messages:
   ```bash
   find /Users/franciscoturdera/PersonalProjects/claude-universe -mindepth 3 -maxdepth 3 -path "*/.lilo-outbox/*.json" -not -path "*/orchestrator/*" -not -path "*/processed/*" 2>/dev/null
   ```
   If empty, output `Nothing new.` and stop. **Stay silent if invoked from cron and nothing is new.**

2. For each message file:
   - Read it.
   - Route via the **team-ops** skill — it owns the schema (`type`, `priority`, `project`, `summary`, `detail`, optional `agent_report`), the routing table (blocker/high → immediate; status/low → batch; etc.), the archive convention (`processed/`), and the `agent-feedback.jsonl` aggregation for `done` messages. Do not re-derive any of that here.

3. Relay to the operator according to team-ops's routing rules. Lead with the `summary`; include `project:` as context; quote the `detail` body verbatim. If the operator is at the terminal, reply terse there; do not dual-post to Telegram.

4. After relay (or batching), move each processed file into the project's `.lilo-outbox/processed/` so the next sweep doesn't see it.

5. For any `done` messages: run the registry-refinement aggregation per `team-ops` step 3 — append per-agent ratings to `./agent-feedback.jsonl`, then check thresholds (2+ `poor` across projects OR 4+ `adequate` with similar notes) and refine the affected `templates/team/.claude/agent-registry/<agent>.md` if needed. Tell the operator what changed.

## Output

- Cron-fired and empty: silent (no output).
- Operator-fired and empty: `Nothing new.`
- Has messages: terse summary per message (one-line each, with project + summary line + key details), grouped if multiple from one project. Then the archive confirmation.
