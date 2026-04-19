---
name: new-project
description: Scaffold a new Claude Code project as a sibling of the orchestrator repo. Use when the operator says "new project <name>", "start a project called X", "spin up X", "scaffold X", or anything equivalent. All projects scaffold with the team template (PM + specialist agents) and auto-launch the PM in tmux.
---

# new-project

Create a new Claude Code project as a sibling directory of the orchestrator
repo. Every project uses the team template — PM + specialist agents, outbox
relay, the whole setup. There is no single-session option.

## Inputs

- `<name>` — project directory name (slug-style, no spaces)

## Steps

Run from the orchestrator repo root, substituting `<name>`:

```bash
DEST=../<name>

mkdir -p "$DEST"
(cd "$DEST" && git init -q)
# Trailing /. copies dotfiles too — do NOT replace with /* or .claude/ is skipped.
cp -R templates/team/. "$DEST"/
# Substitute placeholder in every copied file. perl -pi is cross-platform
# (sed -i differs between BSD/macOS and GNU/Linux).
find "$DEST" -type f -not -path '*/.git/*' -exec perl -pi -e "s/\{\{PROJECT_NAME\}\}/<name>/g" {} +
```

Verify: `ls -la ../<name>` and confirm `.claude/agents/`, `.claude/agent-registry/`,
and `CLAUDE.md` are all present.

Then invoke the `team-ops` skill for the post-scaffold launch steps
(inbox/outbox dirs, initial task file, tmux session, PM kickoff).

Report back that the project is ready and that the PM is running in the
`<name>` tmux session.
