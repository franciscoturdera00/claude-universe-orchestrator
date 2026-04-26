---
name: kill
description: Pre-exit scan for this Lilo session — save memory-worthy lessons silently, ask before committing, list anything that'll outlive the session. Use when the operator says "/kill", "kill the session", "wrap up", or signals the session is ending. NOT for killing PM tmux sessions.
---

# kill

Operator is closing this Lilo session. Find what'd be lost; save the safe stuff; ask about the rest.

## Scan

1. **Memory-worthy moments** — corrections, validated unusual choices, hardware/external-system gotchas, surprising facts about the project. Cross-check against `MEMORY.md` index. Save new ones directly (no permission needed). Err on saving.
2. **Uncommitted git state** — `git status -s`. List modified/untracked files. Draft a commit message and ask whether to commit (and push, if precedent set this session).
3. **Outbox** — silent sweep `../*/.lilo-outbox/*.json`; relay anything queued before exit.
4. **Running tmux** — `tmux ls`. PMs outlive Lilo; list for awareness, don't kill.

## Output

Tight. One line per non-empty category. Group `Saved:` (silent actions taken) and `Needs your call:` (commit/push). End with `Safe to kill once you answer.` or `Nothing to save. Safe to kill.`
