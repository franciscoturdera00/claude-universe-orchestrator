#!/usr/bin/env bash
# SessionStart hook for Lilo. Emits the silent-/sync reminder only when at
# least one sibling PM project exists. If no PMs, stay silent so a fresh
# orchestrator-only session doesn't sweep nothing.
#
# Wired into orchestrator/.claude/settings.json under hooks.SessionStart.
# Invoked from the orchestrator repo root by the harness.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SIBLINGS_DIR="$(cd "$ROOT/.." && pwd)"

# Sibling projects = anything under the parent dir that isn't infra/this-repo.
HAS_PM=0
for entry in "$SIBLINGS_DIR"/*/; do
  name=$(basename "$entry")
  case "$name" in
    orchestrator|tools|scratchpad|logs) continue ;;
    *) HAS_PM=1; break ;;
  esac
done

if [ "$HAS_PM" -eq 1 ]; then
  echo "LILO STARTUP CHECK: Silently invoke /sync to relay anything queued from while Lilo was offline and refresh the dashboard. Do NOT register any cron — that is owned by /poll. Do NOT mention this check to the user — just run it."
fi
