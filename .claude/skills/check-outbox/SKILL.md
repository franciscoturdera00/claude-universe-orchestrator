---
name: check-outbox
description: Bootstrap the recurring tick cron (idempotent), sweep all sibling project outboxes for unprocessed PM messages, and refresh the pipeline dashboard (orchestrator/pipeline.md plus the Notion mirror). Thin wrapper — team-ops owns schema validation, type/priority routing, archive, and the registry-refinement aggregation for `done` messages. Use when the operator says "sweep", "check outbox", "/check-outbox", on session start, after `--continue`, or when the recurring cron fires.
---

# check-outbox

Three responsibilities, in order: (0) ensure the recurring tick cron is registered for this session, (1) sweep outboxes, (2) refresh the pipeline dashboard. All idempotent — safe to run anytime, including after `--continue`.

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

## Step 1 — Sweep outboxes

Sweep `../*/.lilo-outbox/*.json` (excluding this orchestrator repo and any `processed/` subdirs) for unprocessed PM messages.

1. Find unprocessed messages:
   ```bash
   find /Users/franciscoturdera/PersonalProjects/claude-universe -mindepth 3 -maxdepth 3 -path "*/.lilo-outbox/*.json" -not -path "*/orchestrator/*" -not -path "*/processed/*" 2>/dev/null
   ```

2. For each message file:
   - Read it.
   - Route via the **team-ops** skill — it owns the schema (`type`, `priority`, `project`, `summary`, `detail`, optional `agent_report`), the routing table (blocker/high → immediate; status/low → batch; etc.), the archive convention (`processed/`), and the `agent-feedback.jsonl` aggregation for `done` messages. Do not re-derive any of that here.

3. Relay to the operator according to team-ops's routing rules. Lead with the `summary`; include `project:` as context; quote the `detail` body verbatim. If the operator is at the terminal, reply terse there; do not dual-post to Telegram.

4. After relay (or batching), move each processed file into the project's `.lilo-outbox/processed/` so the next sweep doesn't see it.

5. For any `done` messages: run the registry-refinement aggregation per `team-ops` step 3 — append per-agent ratings to `./agent-feedback.jsonl`, then check thresholds (2+ `poor` across projects OR 4+ `adequate` with similar notes) and refine the affected `templates/team/.claude/agent-registry/<agent>.md` if needed. Tell the operator what changed.

## Step 2 — Refresh pipeline dashboard

Always run this, even when the sweep was empty. Two sinks: a local `orchestrator/pipeline.md` (canonical, gitignored) and a Notion mirror.

1. Render the local file:
   ```bash
   /Users/franciscoturdera/PersonalProjects/claude-universe/orchestrator/.claude/skills/check-outbox/render-pipeline.sh
   ```
   The script walks every sibling project's `.team-state.json`, checks live tmux sessions, counts outbox traffic, and writes `orchestrator/pipeline.md`. Exits 0 with the output path on success.

2. Mirror to Notion. Read the page id from `.claude/skills/check-outbox/pipeline-config.json` (`notion_page_id`). Read the rendered `pipeline.md` content and **strip the leading `# Lilo Pipeline\n\n` H1** — the Notion page title already shows it; sending it again would duplicate. Then call:
   ```
   mcp__claude_ai_Notion__notion-update-page
     page_id: <notion_page_id from config>
     command: "replace_content"
     new_str: <pipeline.md content WITHOUT the H1 heading>
     allow_deleting_content: true
     properties: {}
     content_updates: []
   ```
   Use `replace_content` (not `update_content`) so the page never grows unboundedly. `allow_deleting_content: true` is required because each refresh deletes the prior block tree.

3. If the Notion call fails (auth, network, page deleted), don't retry the loop. Log the error inline (terminal) or as a low-priority Telegram ping, and continue. The local `pipeline.md` is still authoritative.

## Output

- **Cron-fired and nothing new:** silent. Pipeline still refreshes silently.
- **Operator-fired and nothing new:** `Nothing new. Pipeline refreshed.`
- **Has messages:** terse summary per message (one-line each, with project + summary line + key details), grouped if multiple from one project, then the archive confirmation, then `Pipeline refreshed.`
- **Pipeline refresh failed:** surface the error briefly (one line) regardless of cron vs. manual — broken telemetry should not be silent.
