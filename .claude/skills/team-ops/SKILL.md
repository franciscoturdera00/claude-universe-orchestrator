---
name: team-ops
description: Team-mode project coordination for Lilo — launching PM sessions on the `team` template, relaying PM outbox messages to the operator by type/priority, and aggregating specialist ratings into the registry-refinement loop. Use when scaffolding a team-template project, sweeping `../<project>/.lilo-outbox/*.json`, or processing `done` messages from PMs.
---

# team-ops

Lilo's playbook for projects. Covers the three coordination duties that are core to every scaffolded project and would otherwise clutter `CLAUDE.md`:

1. Launching a PM session after the scaffold is copied
2. Relaying PM messages from `.lilo-outbox/` to the operator
3. Aggregating agent feedback and refining the shared specialist registry

---

## 1. Launching the PM session

Runs after the `new-project` skill has already copied `templates/team/` into `../<name>/` and substituted `{{PROJECT_NAME}}`. Do these steps in order:

1. Ensure the scaffold included `.claude/agents/`, `.claude/agent-registry/`, and `CLAUDE.md`. The `cp -R templates/team/. ../<name>/` line in the scaffold recipe handles this; verify with `ls -la ../<name>/.claude/`.
2. Create the comms dirs in the project:
   ```bash
   mkdir -p ../<name>/.lilo-inbox ../<name>/.lilo-outbox
   ```
3. **Pre-populate `.claude/agents/` from the full registry BEFORE launching claude.** Claude Code only indexes subagents that exist in `.claude/agents/` at session start — anything copied in later is invisible to the `Agent` tool for the rest of that session, and the PM silently falls back to `general-purpose` dispatches with persona-prepended briefs. To make every registry agent dispatchable by name:
   ```bash
   cp ../<name>/.claude/agent-registry/*.md ../<name>/.claude/agents/
   # Keep the registry README out of the agents dir — it is not a subagent definition.
   rm -f ../<name>/.claude/agents/README.md
   ```
   The PM's "recruitment" phase still chooses which specialists to actually dispatch; pre-populating only makes them all *available* so the Agent tool resolves them.
4. Write the initial task to `../<name>/.lilo-inbox/<timestamp>-initial-task.md`. Content is whatever the operator described as the project goal.
5. Launch the PM in a detached tmux session:
   ```bash
   tmux new -d -s <name> "cd ../<name> && claude --dangerously-skip-permissions --chrome"
   ```
6. Kick off the PM with the check-inbox nudge:
   ```bash
   tmux send-keys -t <name> "Run /check-inbox to read your first task, then start working. Run /check-inbox again at every natural breakpoint (end of phase, after long operations, whenever I nudge you) — new instructions from the operator land there asynchronously. Write status updates to .lilo-outbox/ as you go." Enter
   ```

PM-side behavior (checking the local registry first, maintaining `.team-state.json`, staleness audits on resume) is documented in `templates/team/agents/project-manager.md` and does not need to be restated here.

**Sending further instructions** to a running PM: write to `../<name>/.lilo-inbox/<timestamp>-<slug>.md`, then nudge with `tmux send-keys -t <name> "Run /check-inbox" Enter`.

---

## 2. Outbox relay

PMs write JSON messages to `../<project>/.lilo-outbox/<timestamp>-<slug>.json`:

```json
{
  "type": "status | question | blocker | done | error",
  "priority": "low | normal | high",
  "project": "<project-name>",
  "summary": "<one-line, <= 120 chars>",
  "detail": "<full body, markdown allowed>"
}
```

`done` messages additionally include an `agent_report` array — see section 3.

### Routing rules

| Type      | Priority       | Action                                                      |
|-----------|----------------|-------------------------------------------------------------|
| `blocker` | `high`         | Relay to the operator on Telegram IMMEDIATELY, full detail |
| `error`   | any            | Relay promptly                                              |
| `done`    | any            | Relay promptly, then run section 3 (feedback aggregation)  |
| `question`| `high`/`normal`| Relay promptly                                              |
| `question`| `low`          | Batch with the next relevant relay                          |
| `status`  | `high`/`normal`| Relay                                                       |
| `status`  | `low`          | Batch; never wake the operator                              |

When relaying, lead with the `summary` line and include `project:` as context. Use the `detail` body verbatim — do not rewrite the PM's message.

### Housekeeping

After reading a message and relaying (or batching) it, move the file to `../<project>/.lilo-outbox/processed/` so it is not processed twice. The sweep cron (`7,37 * * * *`) excludes `processed/` subdirs on its next pass.

---

## 3. Agent feedback aggregation

Every `done` message includes an `agent_report` array rating each specialist on the build. Append each rating as its own line to `./agent-feedback.jsonl` at the orchestrator root, with the project name and an ISO timestamp:

```json
{"project": "<name>", "timestamp": "<ISO>", "agent": "code", "rating": "adequate", "notes": "Struggled with async patterns"}
```

### Refinement thresholds

Periodically (during status checks, or when asked) scan `agent-feedback.jsonl` and flag any agent meeting either threshold:

- **3+ `poor` ratings** across different projects, OR
- **5+ `adequate` ratings** with similar `notes` themes (same weakness recurring)

When a threshold is hit, refine `templates/team/.claude/agent-registry/<agent>.md` — update the system prompt, tool scope, or constraints to address the recurring issue. Summarize the refinement and tell the operator what changed. **Do not wait to be asked** — this is the registry's self-improvement loop and only works if you run it.
