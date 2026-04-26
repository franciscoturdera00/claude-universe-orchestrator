---
name: kill
description: Pre-exit scan for this PM session — finalize outbox, persist state, ask before committing. Use when Lilo or the operator says "/kill", "wrap up", "save and close", or signals the PM session is ending. NOT for killing tmux sessions of other projects.
---

# kill

PM session is closing. Find what'd be lost in this project; save the safe stuff; ask about the rest.

## Scan

1. **Outbox** — anything in-flight you haven't sent? Send a final `done` (or `status` if not complete) summarizing where the project stands. Include `agent_report` if you used specialists. Lilo needs this for the feedback loop.
2. **`.team-state.json`** — mark any `in_progress` tasks as `paused` with a one-line note on where they left off. Bump `updated_at`. Resume relies on this.
3. **Project memory** — non-obvious facts learned this session (architectural decisions, gotchas, hardware/external-system quirks) belong in `project-state.md` or equivalent. Save without asking.
4. **Uncommitted git** — `git status -s`. List, draft a commit message, ask whether to commit (and push, if precedent set this session).

## Output

Tight. One line per non-empty category. Group `Saved:` vs `Needs your call:`. End with `Safe to kill once you answer.` or `Nothing to save. Safe to kill.`
