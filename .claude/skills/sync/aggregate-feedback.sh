#!/usr/bin/env bash
# Scan agent-feedback.jsonl for agents meeting the registry-refinement
# thresholds defined in team-ops SKILL.md section 3:
#   - 2+ poor ratings across distinct projects, OR
#   - 4+ adequate ratings (theme inspection happens at the LLM layer)
#
# Emits a single JSON object to stdout:
#   {
#     "flagged": [{ agent, reasons[], poor_count, poor_projects[], adequate_count, adequate_notes[] }, ...],
#     "summary": { agents_seen, flagged_count, total_entries }
#   }
# Always exits 0; if the feed is missing or empty, flagged is [].

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FEED="$ORCHESTRATOR/agent-feedback.jsonl"

if [[ ! -f "$FEED" ]]; then
  echo '{"flagged":[],"summary":{"agents_seen":0,"flagged_count":0,"total_entries":0}}'
  exit 0
fi

jq -s '
  map(select(.rating == "poor" or .rating == "adequate" or .rating == "effective"))
  | . as $all
  | (group_by(.agent) | map({
      agent: .[0].agent,
      total: length,
      poor_count: ([.[] | select(.rating == "poor")] | length),
      poor_projects: ([.[] | select(.rating == "poor") | .project] | unique),
      adequate_count: ([.[] | select(.rating == "adequate")] | length),
      adequate_notes: [.[] | select(.rating == "adequate") | {project, notes, timestamp}],
      effective_count: ([.[] | select(.rating == "effective")] | length)
    })) as $by_agent
  | ($by_agent | map(. + {reasons: (
      ((if (.poor_projects | length) >= 2 then ["poor>=2 across " + ((.poor_projects | length) | tostring) + " projects"] else [] end))
      + ((if .adequate_count >= 4 then ["adequate>=4 (" + (.adequate_count | tostring) + ")"] else [] end))
    )})) as $with_reasons
  | {
      flagged: ($with_reasons | map(select(.reasons | length > 0)) | map({
        agent, reasons, poor_count, poor_projects, adequate_count, adequate_notes, effective_count
      })),
      summary: {
        agents_seen: ($by_agent | length),
        flagged_count: ($with_reasons | map(select(.reasons | length > 0)) | length),
        total_entries: ($all | length)
      }
    }
' "$FEED"
