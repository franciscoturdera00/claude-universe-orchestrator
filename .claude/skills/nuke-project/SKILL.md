---
name: nuke-project
description: Delete a sibling project directory entirely (destructive, irreversible). Use when the operator says "nuke <name>", "delete the <name> project", "tear down X", or anything clearly asking to remove a scaffolded project. ALWAYS confirm with the operator before deleting.
---

# nuke-project

Delete all files for a sibling project and kill its tmux session. Destructive and irreversible.

## Inputs

- `<name>` — project directory name at `../<name>/`

## Steps

1. **ASK THE OPERATOR TO CONFIRM FIRST.** Never proceed without explicit confirmation. Show them what will be deleted (the directory and the tmux session name).
2. Kill any running tmux session for the project:
   ```bash
   tmux kill-session -t <name> 2>/dev/null || true
   ```
3. From the orchestrator repo root, delete the sibling directory:
   ```bash
   rm -rf ../<name>/
   ```
4. Confirm deletion back to the operator.

## Hard rules

- NEVER nuke the orchestrator repo itself (`.`) or anything outside `../`.
- NEVER skip the confirmation step, even if the operator's request sounds urgent.
- If the project has uncommitted changes the operator may want to preserve, surface that before deleting.
