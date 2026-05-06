---
name: kill
description: Pre-exit scan for this PM session — finalize outbox, persist state, commit and push routine changes, branch off anything risky. Use when Lilo or the operator says "/kill", "wrap up", "save and close", or signals the PM session is ending. NOT for killing tmux sessions of other projects.
---

# kill

PM session is closing. Save what'd be lost in this project. Take action — don't ask permission for routine stuff. The operator has pre-authorized commit + push as part of `/kill`.

## Scan — fire in parallel

Run these in a **single message with multiple tool calls** so they execute in parallel. The point: the heavy reads (full `git diff`) burn subagent context, not the PM's.

1. **Agent: `security-reviewer`** — scan the uncommitted diff for secrets, credential paths, and other risk markers (see below). Pass the full risk-marker list and ask for a JSON-shaped report: `{risky: [{path, reason}], skip: [paths]}`.
2. **Agent: `code-reviewer`** *(skip if the diff is trivial)* — quick sanity pass on the routine-looking changes; flag anything half-finished, unsafe, or that you wouldn't be able to justify in one line.
3. **Bash (batched):** `git status -s && git diff --stat` — trivial reads, run inline.

While those run, prepare the parent-only artifacts (these need PM context, can't be subagented):

- **Outbox finalize** — anything in-flight you haven't sent? Send a final `done` (or `status` if not complete) summarizing where the project stands. Include `agent_report` if you used specialists. Lilo needs this for the feedback loop.
- **`.team-state.json`** — mark any `in_progress` tasks as `paused` with a one-line note on where they left off. Bump `updated_at`. Resume relies on this.
- **Project memory** — non-obvious facts learned this session (architectural decisions, gotchas, hardware/external-system quirks) belong in `project-state.md` or equivalent. Save without asking.

## Act

Once the parallel phase returns, merge the findings and classify the uncommitted diff:

- **Skip** = `.env`, `.env.local`, `credentials.*`, `*.pem`, `*.key`, `id_rsa*`, `*.p12` — never commit, even on a branch. List in output.
- **Risky** = whatever `security-reviewer` (or `code-reviewer`) flagged, plus:
  - Changes to `.github/workflows/`, CI config, deploy scripts, shared infra
  - Large binaries (>5 MB) where intent is unclear
  - Anything that would require `--no-verify` to land
  - Anything you don't recognize and can't justify in one line
- **Routine** = the remainder. Pipeline / source you authored this session, test fixes, doc updates, persona/config edits the operator already saw via outbox, artifacts from specialists.

Then act:

- **Routine** → stage, commit, push to the current branch (default `main`; if precedent in this session was a feature branch like `feat/...`, stay on that branch).
- **Risky** → stash, create branch `kill/<short-slug>` off the current commit, restore on the branch, commit, push the branch. Do NOT merge to main.
- **Mixed** → split per-file. Routine to working branch as one commit; risky to `kill/<slug>` as a separate commit. Both pushed.

### Risk markers reference (for the security-reviewer prompt)

- File contents matching `(?i)(api[_-]?key|secret|token|bearer|password)\s*[:=]`
- File path under `.env*`, `credentials.*`, `*.pem`, `*.key`, `id_rsa*`, `*.p12`
- `.github/workflows/`, CI config, deploy scripts
- Binaries >5 MB
- Anything triggering a precommit hook failure

### Hard rules

- Never `--amend` a published commit.
- Never push with `--force` / `--force-with-lease`.
- Never bypass hooks. If a hook fails, fix the cause or branch off — do not pass `--no-verify`.
- Never commit `.env*` (except `.env.example`).

## Output

Tight. One line per non-empty category. Two groups: `Done:` (actions taken — outbox sent, state checkpointed, commits pushed) and `Needs your call:` (only when something was branched off or skipped). End with `Safe to kill.` or, if you isolated something, `Safe to kill — review <branch> when you're back.`
