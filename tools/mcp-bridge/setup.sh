#!/usr/bin/env bash
# Bootstrap the MCP bridge venv. Idempotent — safe to re-run.
#
# Creates ./tools/mcp-bridge/.venv/ and installs requirements.txt into it.
# Run from the orchestrator repo root:
#   ./tools/mcp-bridge/setup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$HERE/.venv"

if [ ! -d "$VENV" ]; then
  echo "Creating venv at $VENV"
  python3 -m venv "$VENV"
fi

echo "Installing/updating requirements"
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q -r "$HERE/requirements.txt"

echo "Done. Bridge ready at $VENV/bin/python"
