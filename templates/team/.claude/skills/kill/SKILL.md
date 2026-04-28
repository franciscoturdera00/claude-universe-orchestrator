---
name: kill
description: Pre-exit scan for this PM session — finalize outbox, persist state, commit and push routine changes, branch off anything risky. Use when Lilo or the operator says "/kill", "wrap up", "save and close", or signals the PM session is ending. NOT for killing tmux sessions of other projects.
---

# kill

PM session is closing. Save what'd be lost in this project. Take action — don't ask permission for routine stuff. The operator has pre-authorized commit + push as part of `/kill`.

## Scan

1. **Outbox** — anything in-flight you haven't sent? Send a final `done` (or `status` if not complete) summarizing where the project stands. Include `agent_report` if you used specialists. Lilo needs this for the feedback loop.

2. **`.team-state.json`** — mark any `in_progress` tasks as `paused` with a one-line note on where they left off. Bump `updated_at`. Resume relies on this.

3. **Project memory** — non-obvious facts learned this session (architectural decisions, gotchas, hardware/external-system quirks) belong in `project-state.md` or equivalent. Save without asking.

4. **Uncommitted git state** — `git status -s`. Split changes into ROUTINE and RISKY (see below), then act:
   - **Routine:** stage, draft a one-line commit message, commit, push to the current branch. Default is `main`; if precedent in this session was a feature branch (`fanvue-rest-api`, `feat/...`), stay on that branch. Report what was done.
   - **Risky:** stop. Stash the risky change, create a new branch named `kill/<short-slug>` off the current commit, restore the change there, commit on that branch, push the branch (do NOT merge to main). Report the branch name and why it was isolated so the operator can review.
   - **Mixed:** split the diff per-file. Routine files go to the working branch as one commit; risky files go to `kill/<slug>` as a separate commit. Both get pushed.

### Risk markers — branch off if any apply

- File contents look like secrets: API keys, tokens, passwords, OAuth credentials, anything matching `(?i)(api[_-]?key|secret|token|bearer|password)\s*[:=]`.
- File path is `.env`, `.env.local`, `credentials.*`, `*.pem`, `*.key`, `id_rsa*`, `*.p12` — never commit these even on a branch; list them in the output as skipped entirely.
- Large binary files (>5 MB) where intent is unclear.
- Changes to `.github/workflows/`, CI config, deploy scripts, or shared infra.
- Changes that would require `--no-verify` to land (a precommit hook is failing). Never bypass — branch off and flag.
- Anything you genuinely don't recognize and can't justify in one line.

### What "routine" looks like

- Pipeline / source code you authored or modified in this session and can explain.
- Test fixes.
- Doc / README updates.
- Persona JSON / config edits the operator already saw via outbox.
- New caption / prompt artifacts produced by `lora-prompt-builder` or similar specialists.

### Hard rules

- Never `--amend` a published commit.
- Never push with `--force` / `--force-with-lease`.
- Never bypass hooks. If a hook fails, fix the cause or branch off — do not pass `--no-verify`.
- Never commit `.env*` (except `.env.example`).

## Output

Tight. One line per non-empty category. Two groups: `Done:` (actions taken — outbox sent, state checkpointed, commits pushed) and `Needs your call:` (only when something was branched off or skipped). End with `Safe to kill.` or, if you isolated something, `Safe to kill — review <branch> when you're back.`
