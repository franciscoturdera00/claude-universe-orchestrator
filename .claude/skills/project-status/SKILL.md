---
name: project-status
description: Report which sibling projects exist and which have live tmux sessions. Use when the operator says "status", "what projects do I have", "what's running", "show me my projects", or anything equivalent.
---

# project-status

List the scaffolded sibling projects and any currently-running tmux sessions.

## Steps

Run from the orchestrator repo root:

```bash
ls -1 .. | grep -Ev '^(orchestrator|tools|scratchpad|logs)$'
tmux ls 2>/dev/null || true
```

The first command lists project directories (excluding the orchestrator itself and infra dirs). The second shows active tmux sessions — typically team-mode PMs.

Report both lists concisely. If a project directory exists but has no tmux session, note that it is idle. If a session is active, mention its name.
