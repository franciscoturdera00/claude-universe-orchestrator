---
name: kill
description: Pre-exit scan for this Lilo session — save memory-worthy lessons silently, commit and push routine changes, branch off anything risky. Use when the operator says "/kill", "kill the session", "wrap up", or signals the session is ending. NOT for killing PM tmux sessions.
---

# kill

Operator is closing this Lilo session. Save what'd be lost. Take action — don't ask permission for routine stuff. The operator has pre-authorized commit + push as part of `/kill`.

## Scan

1. **Memory-worthy moments** — corrections, validated unusual choices, hardware/external-system gotchas, surprising facts about the project. Cross-check against `MEMORY.md` index. Save new ones directly (no permission needed). Err on saving.

2. **Outbox** — silent sweep `../*/.lilo-outbox/*.json`; relay anything queued before exit.

3. **Running tmux** — `tmux ls`. PMs outlive Lilo; list for awareness, don't kill.

4. **Uncommitted git state** — `git status -s`. Split changes into ROUTINE and RISKY (see below), then act:
   - **Routine:** stage, draft a one-line commit message, commit, push to the current branch. Default is `main`; that's fine. Report what was done.
   - **Risky:** stop. Stash the risky change, create a new branch named `kill/<short-slug>` off the current commit, restore the change there, commit on that branch, push the branch (do NOT merge to main). Report the branch name and why it was isolated so the operator can review.
   - **Mixed:** split the diff per-file. Routine files go to main as one commit; risky files go to the `kill/<slug>` branch as a separate commit. Both get pushed.

### Risk markers — branch off if any apply

- File contents look like secrets: API keys, tokens, passwords, OAuth credentials, anything matching `(?i)(api[_-]?key|secret|token|bearer|password)\s*[:=]`.
- File path is `.env`, `.env.local`, `credentials.*`, `*.pem`, `*.key`, `id_rsa*`, `*.p12` — never commit these even on a branch; instead, list them in the output and tell the operator they were skipped entirely.
- Large binary files (>5 MB) where intent is unclear — could be incidental.
- Changes to `.github/workflows/`, CI config, deploy scripts, or anything that runs in shared infrastructure.
- Changes that would require `--no-verify` to land (a precommit hook is failing). Never bypass — branch off and flag.
- Anything you genuinely don't recognize and can't justify in one line.

### What "routine" looks like

- Skill / agent-registry / template edits inside this repo.
- Doc edits.
- `.gitignore` adjustments.
- New tools added under `tools/` with sensible content.
- Anything you authored in this session and could explain in one sentence.

### Hard rules

- Never `--amend` a published commit.
- Never push with `--force` / `--force-with-lease`.
- Never bypass hooks. If a hook fails, fix the cause or branch off — do not pass `--no-verify`.
- Never commit `.env*` (except `.env.example`).

## Output

Tight. One line per non-empty category. Two groups: `Done:` (actions taken) and `Needs your call:` (only when something was branched off or skipped). End with `Safe to kill.` or, if you isolated something onto a branch, `Safe to kill — review <branch> when you're back.`
