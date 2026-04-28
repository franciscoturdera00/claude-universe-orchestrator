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

5. For any `done` messages: append per-agent ratings to `./agent-feedback.jsonl` per the canonical schema in team-ops section 3 (`rating` MUST be one of `poor` / `adequate` / `effective`).

## Step 1.5 — Registry-refinement scan

Run the deterministic aggregator on every tick (cron or manual). It scans `agent-feedback.jsonl` and surfaces any specialist meeting the team-ops thresholds:

```bash
.claude/skills/check-outbox/aggregate-feedback.sh
```

Output is JSON: `{flagged: [...], summary: {agents_seen, flagged_count, total_entries}}`.

- `flagged_count == 0`: silent (don't surface noise to the operator).
- `flagged_count > 0`: each entry has `agent`, `reasons[]`, `poor_count`, `poor_projects[]`, `adequate_count`, `adequate_notes[]`. Read `templates/team/.claude/agent-registry/<agent>.md`, eyeball the adequate-notes themes (the script flags candidates; only the LLM can judge whether the notes share a coherent weakness), and decide whether to refine the spec. If you do refine, summarize the change to the operator and tell them what file to commit.
- Failures (jq missing, malformed feed) — surface the error briefly but don't abort the dashboard refresh.

## Step 2 — Refresh pipeline dashboard

Always run this, even when the sweep was empty.

### 2.1 Render data

```bash
.claude/skills/check-outbox/render-pipeline.sh
```

Run from the orchestrator repo root. Outputs `pipeline.md` (human inspection) and `pipeline.json` (structured data, source of truth for the upsert) in the orchestrator root.

### 2.2 Read state

Read both files. From `pipeline-config.json` you need: `data_source_id`, `notion_page_id`, `project_rows` (cached per-project sync record), `parent_fingerprint` (cached inputs to the parent page). From `pipeline.json` you need: `snapshot`, `projects`, `recent_activity`.

**Cache shape (per project):**

```json
"project_rows": {
  "<name>": {
    "page_id": "<uuid>",
    "props": { ...exact property record last sent to Notion... },
    "body_updated_at": "<ISO timestamp last used to render body, or null>"
  }
}
```

**Backward-compat:** if `project_rows[name]` is a bare string (legacy), treat it as `{page_id: <string>, props: {}, body_updated_at: null}` — both diffs will trip and the row will be fully re-synced once, then rewritten in the new shape during step 2.5.

**Parent fingerprint shape:**

```json
"parent_fingerprint": {
  "snapshot": {"active": N, "paused": N, "blocked": N, "done": N, "solo": N, "live_pms": ["..."]},
  "what_next": [{"name": "...", "status": "...", "pm_live": false, "phase": "...", "next_action": "..."}, ...],
  "recent_top5": ["<ts>|<project>|<type>|<summary>", ...]
}
```

Missing or empty `parent_fingerprint` → treat as needing a full parent refresh.

### 2.3 Upsert each project row (parallel calls in one message)

For every entry in `pipeline.json.projects`:

**Properties (always sent):**
- `Name` ← `project.name`
- `Status` ← normalize `project.status`:
  - direct match `["active","paused","blocked","done","solo"]` → use as-is
  - `complete`, `completed`, `completed_with_issues`, `closed`, `finished` → `done`
  - `in_progress` → `active`
  - `unknown`, empty, null → `solo`
  - anything else (long free-text statuses, e.g. job-apply) → `active`
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

**Skip-if-unchanged (cost control — this is the load-bearing optimization):**

For each project, compute the property record above as `current_props`. Then diff against the cache:

- `props_changed` = `current_props != cached.props` (field-by-field equality; missing/legacy cache → always changed)
- `body_changed` = `project.has_state` AND `project.updated_at != cached.body_updated_at` (state file mtime is a complete proxy for body change since every body section is sourced from `.team-state.json`; outbox counts and pm_live don't appear in the body)

**Dispatch order per project (all in parallel — single assistant message for the whole batch):**

- **Not in cache** (truly new project): call `notion-create-pages` with `parent: {type: "data_source_id", data_source_id: config.data_source_id}` and a single page entry including BOTH the properties and (for non-solo) the `content` field with the composed body. Save the returned `id` for step 2.5.
- **In cache, both diffs false:** issue NO Notion calls for this project. The cached state already matches.
- **In cache, only `props_changed`:** call `notion-update-page` once with `command: "update_properties"` on `cached.page_id`, carrying the properties block.
- **In cache, only `body_changed`** (rare — implies state mtime moved without any property field shifting): call `notion-update-page` once with `command: "replace_content"`, `allow_deleting_content: true`, `new_str: <composed body>`, empty `properties` and `content_updates`. Skip for solo projects.
- **In cache, both changed:** both calls (`update_properties` then `replace_content`).

Issue every required call across all projects in a single assistant message so they execute concurrently. Steady-state ticks (no projects moved) issue zero per-project calls.

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

**Skip-if-unchanged for the parent page:**

Compute `current_fingerprint`:

```json
{
  "snapshot": pipeline.snapshot,                                    // {active, paused, blocked, done, solo, live_pms (sorted)}
  "what_next": [{"name", "status", "pm_live", "phase", "next_action"}, ...],   // every bullet rendered above, in the order rendered
  "recent_top5": ["<timestamp>|<project>|<type>|<summary>", ...]    // top 5 of recent_activity
}
```

If `current_fingerprint` deep-equals `config.parent_fingerprint`, skip the parent-page call entirely. Otherwise send via `notion-update-page`: `page_id: config.notion_page_id`, `command: "replace_content"`, `allow_deleting_content: true`, `new_str: <composed>`, empty `properties` and `content_updates`. Cache the new fingerprint in step 2.5.

### 2.5 Persist sync cache

After dispatch (whether anything was sent or not), rewrite `.claude/skills/check-outbox/pipeline-config.json` so the next tick can skip unchanged rows. Use Write, not Edit — the file is small and JSON-shaped. Preserve unrelated fields (`notion_page_id`, `data_source_id`, paths, etc.).

**For `project_rows`:** every project in `pipeline.json.projects` gets a fresh entry:

```json
"<name>": {
  "page_id": "<existing cached id, or returned id from a 2.3 create>",
  "props": <the exact current_props record you computed in 2.3>,
  "body_updated_at": <project.updated_at, or null for solo>
}
```

This is true even for projects whose diff was empty — rewriting the cache with the same values is a no-op but keeps the schema uniform. Drop entries for projects that no longer appear in `pipeline.json` (renamed/nuked).

**For `parent_fingerprint`:** write the `current_fingerprint` you computed in 2.4, regardless of whether the parent page call was sent or skipped.

If a Notion call failed in 2.3 or 2.4 for a specific project/parent, do NOT update its cache entry — leaving the old (or missing) cache forces a retry on the next tick. Successful calls update the cache; failures don't.

### 2.6 Failure handling

- If render-pipeline.sh exits non-zero: surface the error briefly (one line) and stop the dashboard refresh — do not partial-update.
- If a single Notion call fails: continue with the others. Note the failure in your reply summary. The next tick will reconcile.
- Never duplicate rows: if you suspect the cache is stale (project name in JSON but no cached id, AND the database already has a row with that name), use `notion-search` to find it and write its id into the cache instead of creating a new row.

## Output

- **Cron-fired and nothing new in outboxes:** silent. Dashboard refreshes silently.
- **Operator-fired and nothing new:** `Nothing new. Pipeline refreshed.`
- **Has outbox messages:** terse summary per message (one-line each), grouped if multiple from one project, then archive confirmation, then `Pipeline refreshed.`
- **Pipeline refresh failed (any reason):** surface the error briefly (one line) regardless of cron vs. manual — broken telemetry should not be silent.
