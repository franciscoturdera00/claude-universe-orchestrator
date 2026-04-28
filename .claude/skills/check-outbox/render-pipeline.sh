#!/usr/bin/env bash
# Render orchestrator/pipeline.md from the current state of every sibling
# project in claude-universe/. Run from the orchestrator repo root or
# anywhere — paths are absolute. Idempotent.

set -euo pipefail

ROOT="/Users/franciscoturdera/PersonalProjects/claude-universe"
OUT="$ROOT/orchestrator/pipeline.md"

LIVE_SESSIONS="$(tmux ls 2>/dev/null | cut -d: -f1 | sort -u || true)"

declare -a active=() paused=() done_p=() no_state=()

for dir in "$ROOT"/*/; do
  name="$(basename "$dir")"
  case "$name" in
    orchestrator|scratchpad|logs|tools) continue ;;
  esac
  state="$dir.team-state.json"
  if [[ ! -f "$state" ]]; then
    no_state+=("$name")
    continue
  fi
  status="$(jq -r '.status // "unknown"' "$state" 2>/dev/null || echo unknown)"
  case "$status" in
    active|in_progress) active+=("$name") ;;
    paused|blocked) paused+=("$name") ;;
    done|complete|completed) done_p+=("$name") ;;
    *) active+=("$name") ;;
  esac
done

render_project() {
  local p="$1"
  local state="$ROOT/$p/.team-state.json"
  local phase status updated summary team_count tasks_open
  phase="$(jq -r '.phase // "-" | tostring | .[:40]' "$state" 2>/dev/null || echo '-')"
  status="$(jq -r '.status // "-" | tostring | .[:40]' "$state" 2>/dev/null || echo '-')"
  updated="$(jq -r '.updated_at // "-"' "$state" 2>/dev/null || echo '-')"
  summary="$(jq -r '.summary // ""' "$state" 2>/dev/null || echo '')"
  team_count="$(jq -r '(.team // []) | length' "$state" 2>/dev/null || echo 0)"
  tasks_open="$(jq -r '
    ((.active_tasks // .tasks // [])
      | map(select((.status // "") | test("^(done|complete|completed|completed_with_issues|closed|finished|cancelled|canceled)$") | not))
      | length)' "$state" 2>/dev/null || echo 0)"

  local live="idle"
  if [[ -n "$LIVE_SESSIONS" ]] && echo "$LIVE_SESSIONS" | grep -qx "$p"; then
    live="LIVE"
  fi

  local outbox_pending outbox_archived
  outbox_pending="$(find "$ROOT/$p/.lilo-outbox" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
  outbox_archived="$(find "$ROOT/$p/.lilo-outbox/processed" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"

  printf '### %s -- %s (%s)\n' "$p" "$phase" "$status"
  printf '_Updated: %s | PM: %s | Team: %s | Open tasks: %s | Outbox: %s pending / %s archived_\n\n' \
    "$updated" "$live" "$team_count" "$tasks_open" "$outbox_pending" "$outbox_archived"
  if [[ -n "$summary" ]]; then
    printf '%s\n\n' "$summary"
  fi

  local first_task
  first_task="$(jq -r '
    ((.active_tasks // .tasks // [])
      | map(select((.status // "") | test("^(done|complete|completed|completed_with_issues|closed|finished|cancelled|canceled)$") | not))
      | .[0:3]
      | map("- **" + (.id // "?") + "** (" + (.status // "?") + "): " + ((.description // .note // "") | gsub("\n"; " ") | .[:200]))
      | join("\n"))
    // ""' "$state" 2>/dev/null || true)"
  if [[ -n "$first_task" ]]; then
    printf '%s\n\n' "$first_task"
  fi
}

recent_outbox() {
  find "$ROOT" -mindepth 4 -maxdepth 4 -path "*/.lilo-outbox/processed/*.json" \
    -not -path "*/orchestrator/*" 2>/dev/null \
    | xargs -I{} stat -f "%m %N" {} 2>/dev/null \
    | sort -rn \
    | head -5 \
    | while read -r mtime path; do
        local proj msg ts
        proj="$(echo "$path" | sed -E "s|$ROOT/([^/]+)/.*|\1|")"
        msg="$(jq -r '"\(.type) | \(.summary // "")"' "$path" 2>/dev/null || echo unreadable)"
        ts="$(date -r "$mtime" -u +'%Y-%m-%d %H:%MZ' 2>/dev/null || echo "?")"
        printf -- '- %s -- **%s** %s\n' "$ts" "$proj" "$msg"
      done
}

{
  printf '# Lilo Pipeline\n\n'
  printf '_Updated: %s_\n\n' "$(date -u +'%Y-%m-%d %H:%M UTC')"

  printf 'Projects: %d active, %d paused/blocked, %d done, %d solo (no team-state)\n\n' \
    "${#active[@]}" "${#paused[@]}" "${#done_p[@]}" "${#no_state[@]}"

  if [[ ${#active[@]} -gt 0 ]]; then
    printf '## Active\n\n'
    for p in "${active[@]}"; do render_project "$p"; done
  fi

  if [[ ${#paused[@]} -gt 0 ]]; then
    printf '## Paused / Blocked\n\n'
    for p in "${paused[@]}"; do render_project "$p"; done
  fi

  if [[ ${#done_p[@]} -gt 0 ]]; then
    printf '## Done\n\n'
    for p in "${done_p[@]}"; do render_project "$p"; done
  fi

  if [[ ${#no_state[@]} -gt 0 ]]; then
    printf '## Solo projects (no team-state)\n\n'
    for p in "${no_state[@]}"; do printf -- '- %s\n' "$p"; done
    printf '\n'
  fi

  printf '## Recent outbox activity (last 5 archived messages)\n\n'
  out="$(recent_outbox)"
  if [[ -z "$out" ]]; then
    printf '_No archived outbox messages._\n'
  else
    printf '%s\n' "$out"
  fi
} > "$OUT"

echo "$OUT"
