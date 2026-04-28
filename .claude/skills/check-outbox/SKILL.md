---
name: check-outbox
description: Bootstrap the recurring tick cron (idempotent), sweep all sibling project outboxes for unprocessed PM messages, and refresh the pipeline dashboard (pipeline.md locally + Notion Projects database + Lilo Pipeline parent page). Thin wrapper — team-ops owns schema validation, type/priority routing, archive, and the registry-refinement aggregation for `done` messages. Use when the operator says "sweep", "check outbox", "/check-outbox", on session start, after `--continue`, or when the recurring cron fires.
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

Stay silent about this step unless something failed.

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

Always run this, even when the sweep was empty.

### 2.1 Render data

```bash
.claude/skills/check-outbox/render-pipeline.sh
```

Run from the orchestrator repo root. Outputs `pipeline.md` (human inspection) and `pipeline.json` (structured data, source of truth for the upsert) in the orchestrator root.

### 2.2 Read state

Read both files. From `pipeline-config.json` you need: `data_source_id`, `notion_page_id`, `project_rows` (cached `name → page_id` map). From `pipeline.json` you need: `snapshot`, `projects`, `recent_activity`.

### 2.3 Upsert each project row (parallel calls in one message)

For every entry in `pipeline.json.projects`:

**Properties (always sent):**
- `Name` ← `project.name`
- `Status` ← `project.status` if it matches one of `["active","paused","blocked","done","solo"]`, else fall back: `paused` → `paused`, `unknown`/empty → `solo`. Long sentences in `.status` (e.g. job-apply) → `active`.
- `Phase` ← `project.phase || ""` (truncate to 60 chars)
- `date:Updated:start` ← `project.updated_at` (only if non-null; omit otherwise)
- `date:Updated:is_datetime` ← `1` (only if updated_at is non-null)
- `Team` ← `project.team_size`
- `Open tasks` ← `project.open_tasks_count`
- `Outbox pending` ← `project.outbox_pending`
- `Outbox archived` ← `project.outbox_archived`
- `PM live` ← `"__YES__"` if `project.pm_live` else `"__NO__"`
- `Summary` ← `project.summary` truncated to 500 chars
- `Top tasks` ← top 3 of `project.active_tasks` formatted as `"id (status) -- description"` (each truncated to 120 chars), joined with `\n`. Empty string if no active tasks.

**Body (composed markdown, sent via `replace_content`):**

Skip the body refresh entirely for `has_state: false` (solo) projects — they have nothing meaningful to render. For `has_state: true` projects:

```markdown
## Summary

<project.summary>

## Active tasks

- [ ] **<id>** (<status>) — <description or note>
... (one per active_task)

## Team

- **<name>** (<model>) — <role>
... (one per team member)

## Open decisions

- <decision>
... (one per open_decisions item)

## Context

<context>

## Local path

`<local_path>`
```

Omit any section whose source array is empty. If both `summary` and `context` are empty, the body is just `## Local path`.

**Dispatch order per project:**

- If `project.name` IS a key in `config.project_rows`: call `notion-update-page` twice on the same `page_id` — first with `command: "update_properties"` carrying the properties block; second with `command: "replace_content"`, `allow_deleting_content: true`, `new_str: <composed body>`, empty `properties` and `content_updates`. Skip the second call for solo projects.
- If `project.name` is NOT in `config.project_rows`: call `notion-create-pages` with `parent: {type: "data_source_id", data_source_id: config.data_source_id}` and a single page entry including BOTH the properties and (for non-solo) the `content` field with the composed body. Save the returned `id` in a local map keyed by name — you'll write it back to config in 2.5.

**Make the calls in parallel** — issue all per-project tool calls in a single assistant message so they execute concurrently. Sequential mode is too slow at 14+ rows.

### 2.4 Regenerate the parent page

Compose the Lilo Pipeline page content from `pipeline.json`:

```markdown
<callout icon="🔭" color="blue_bg">
	Live cross-project status, refreshed every 30 minutes by Lilo's `/check-outbox` cron tick. Click into the Projects table for full per-project context.
</callout>

## Snapshot

**<active>** active ・ **<paused>** paused ・ **<blocked>** blocked ・ **<done>** done ・ **<solo>** solo

Live PMs: <comma-joined live_pms list, or "*none*"> 

---

## What's next

- **<project>** — *<derived next-action line>* {color="<traffic_color>"}
... (one bullet per non-done, non-solo project, sorted: blocked first, then paused, then active; live PMs jump to top of their tier)

---

## Recent activity

- **<timestamp>** — `<project>` <type> | <summary>
... (top 5 of `recent_activity`)

---

## Projects

<database url="https://www.notion.so/275dbe958b27465593c8844c453b12a4" inline="true">Projects</database>
```

Next-action derivation (concise — one short clause):
- `status=blocked` → `*blocked:* <first line of summary>` color=red
- `status=paused` → `*resume:* <first active_task description, else first line of summary>` color=yellow
- `status=active` and `pm_live=true` → `*PM live:* <phase>` color=green
- `status=active` → `*next:* <derive from summary tail or first active_task>` color=green

Truncate any next-action to 160 chars.

Send via `notion-update-page`: `page_id: config.notion_page_id`, `command: "replace_content"`, `allow_deleting_content: true`, `new_str: <composed>`, empty `properties` and `content_updates`.

### 2.5 Persist new row IDs

If you created any rows in 2.3 (i.e. project names not previously in `config.project_rows`), write the updated config back to `.claude/skills/check-outbox/pipeline-config.json` so the next tick uses the cached IDs instead of creating duplicates. Preserve all other fields. Use the Write tool, not Edit, since the file is small and JSON-shaped.

### 2.6 Failure handling

- If render-pipeline.sh exits non-zero: surface the error briefly (one line) and stop the dashboard refresh — do not partial-update.
- If a single Notion call fails: continue with the others. Note the failure in your reply summary. The next tick will reconcile.
- Never duplicate rows: if you suspect the cache is stale (project name in JSON but no cached id, AND the database already has a row with that name), use `notion-search` to find it and write its id into the cache instead of creating a new row.

## Output

- **Cron-fired and nothing new in outboxes:** silent. Dashboard refreshes silently.
- **Operator-fired and nothing new:** `Nothing new. Pipeline refreshed.`
- **Has outbox messages:** terse summary per message (one-line each), grouped if multiple from one project, then archive confirmation, then `Pipeline refreshed.`
- **Pipeline refresh failed (any reason):** surface the error briefly (one line) regardless of cron vs. manual — broken telemetry should not be silent.
