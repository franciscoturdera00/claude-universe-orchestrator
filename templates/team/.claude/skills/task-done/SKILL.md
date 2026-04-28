---
name: task-done
description: Close out a task — append a `task_done` event to `.team-history.jsonl` and remove it from `active_tasks` in `.team-state.json`. Use whenever a task in `active_tasks` is finished. Optional `--rating effective|adequate|poor` records the agent's performance for the registry refinement loop.
user-invocable: true
allowed-tools:
  - Bash(jq *)
  - Bash(date *)
  - Bash(mv *)
  - Bash(cat *)
  - Bash(test *)
---

# /task-done — Evict a finished task from live state

Two-file eviction enforced by the slim-state contract: append a `task_done` event to `.team-history.jsonl`, then delete the task from `active_tasks` in `.team-state.json`. This skill does both atomically so it is impossible to forget one half.

## Usage

```
/task-done <task-id> [--rating effective|adequate|poor]
```

- `<task-id>` — required. Must match an `id` in `.team-state.json`'s `active_tasks`.
- `--rating` — optional. Records how the assigned agent performed; flows into `agent-feedback.jsonl` via the next `done` outbox message and feeds the registry refinement loop. Omit if no specialist was assigned (or if you don't have a clean read on quality).

## Steps

1. **Validate args.** If `<task-id>` is missing, abort with `Usage: /task-done <id> [--rating effective|adequate|poor]`. If `--rating` is present, the value must be one of `effective`, `adequate`, `poor` — anything else is a typo, abort.

2. **Run the eviction script** (single command — uses `jq` for atomic rewrite):

   ```bash
   ID="<task-id>"
   RATING=""  # set to effective|adequate|poor if --rating was passed, else leave empty

   # Confirm task exists before touching anything
   TASK=$(jq --arg id "$ID" '.active_tasks[] | select(.id == $id)' .team-state.json)
   if [ -z "$TASK" ]; then
     # No-op with warning — already evicted, or never existed
     echo "WARN: task '$ID' not in active_tasks. Already evicted? No changes made."
     exit 0
   fi

   TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   SUMMARY=$(echo "$TASK" | jq -r '.description // ""')
   AGENT=$(echo "$TASK" | jq -r '.assigned_to // ""')

   EVENT=$(jq -nc \
     --arg ts "$TS" --arg id "$ID" --arg summary "$SUMMARY" \
     --arg agent "$AGENT" --arg rating "$RATING" '
     {
       ts: $ts,
       kind: "task_done",
       data: ({id: $id, summary: $summary}
         + (if $agent  != "" then {agent:  $agent}  else {} end)
         + (if $rating != "" then {rating: $rating} else {} end))
     }')

   # Append event to history (creates the file if absent)
   echo "$EVENT" >> .team-history.jsonl

   # Rewrite state: drop the task, bump updated_at. Atomic via temp + mv.
   jq --arg id "$ID" --arg ts "$TS" \
     '.active_tasks |= map(select(.id != $id)) | .updated_at = $ts' \
     .team-state.json > .team-state.json.tmp && mv .team-state.json.tmp .team-state.json

   # Confirm
   echo "$EVENT"
   echo "active_tasks: $(jq '.active_tasks | length' .team-state.json)"
   ```

3. **Print the result inline.** The script's last two lines (the event JSON and the new active count) are the canonical confirmation — show them to the operator/Lilo.

## Edge cases

- **Task not in `active_tasks`** — the script prints a `WARN:` and exits 0 without modifying anything. This makes the skill idempotent: re-running on an already-evicted id is safe.
- **No `assigned_to`** — `agent` is omitted from the event (handled by the conditional in the jq builder). Same for `rating`.
- **`.team-history.jsonl` doesn't exist yet** — `>>` creates it on first append.
- **Rewrite mid-flight failure** — the `&& mv` chain means a failed `jq` leaves `.team-state.json` untouched (the temp file is never moved). The history append already happened, so on retry the script will WARN and exit 0 cleanly.

## When to run

- Immediately when a task transitions to `done`. Don't batch — letting completed tasks linger in `active_tasks` is the exact failure mode the slim-state contract is designed to prevent.
- Before writing a `done` outbox message for a phase or milestone. The outbox `agent_report` should match what's in history.
- **Not** for `paused` or `blocked` tasks — those stay in `active_tasks` with status updated, not evicted.
