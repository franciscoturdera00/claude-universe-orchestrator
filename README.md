# orchestrator (Lilo)

The control plane for the `claude-universe` workspace. A long-lived
Claude Code session named **Lilo** that scaffolds projects, launches PM
teams, relays their messages back to the operator, and owns the shared
tool registry. Sibling project code is off-limits — Lilo only writes to
this repo (which contains its own `tools/` framework) and sibling
projects' `.lilo-inbox/` and `.lilo-outbox/`.

`CLAUDE.md` is the source of truth for behavior. This file is the map.

## Expected layout

Lilo assumes this repo lives alongside its projects. The MCP tools
framework lives inside this repo, not as a sibling:

    claude-universe/
      orchestrator/        <- this repo (Lilo runs here)
        tools/             <- MCP tools bridge + registry (in-repo)
      <project-a>/         <- scaffolded project
      <project-b>/         <- scaffolded project

Sibling projects live at `../<name>/` relative to the orchestrator root.
The tools framework is at `./tools/`.

## Repo contents

    orchestrator/
      CLAUDE.md              # Lilo's operating manual (imports @USER.md)
      USER.md.example        # committed template for the operator profile
      USER.md                # gitignored — your actual profile, created during `bootstrap`
      BOOTSTRAP.md           # first-run script Lilo follows when you say `bootstrap`
      ARCHITECTURE.md        # tmux layout, team mode, MCP notes
      README.md              # this file
      agent-feedback.jsonl   # aggregated PM ratings for registry agents
      .mcp.json              # claude-universe-tools + playwright servers
      .claude/
        settings.json        # permissions + UserPromptSubmit startup hook
        skills/              # new-project, nuke-project, project-status, team-ops, tailor-resume, toolify
      templates/
        team/                # PM scaffold: agent-registry, agents/, skills/, CLAUDE.md

## Running Lilo

From this repo's root:

```bash
caffeinate -is claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --chrome
```

Flag by flag:

- `caffeinate -i -s` — keeps the Mac awake (and prevents idle sleep)
  while Lilo is running. Required so the outbox sweep cron keeps firing
  overnight; without it the machine sleeps and Lilo misses PM messages.
- `--channels plugin:telegram@claude-plugins-official` — loads the
  official Telegram plugin channel so the operator can reach Lilo from
  their phone and Lilo can reply with messages/files.
- `--dangerously-skip-permissions` — Lilo scaffolds, edits, and moves
  files autonomously; interactive permission prompts defeat the point.
  The wide-open `Write/Edit/Read` globs in `.claude/settings.json`
  assume this flag.
- `--chrome` — attaches the `claude-in-chrome` extension so Lilo can
  drive a browser for skills like `tailor-resume` (Indeed/LinkedIn
  fetches) and `job-apply` (Greenhouse/Lever form fill). Install the
  extension in Chrome first: https://claude.ai/download

Wrap in tmux if you want the session to survive terminal restarts:

```bash
tmux new -s lilo "caffeinate -is claude --channels plugin:telegram@claude-plugins-official --dangerously-skip-permissions --chrome"
```

### Recommended MCPs

Lilo only needs four MCP integrations to do its job:

| Source | Name | Why |
|--------|------|-----|
| This repo's `.mcp.json` | `claude-universe-tools` (custom) | Dynamic bridge over `./tools/registry.json` — any registered tool becomes callable |
| This repo's `.mcp.json` | `playwright` | Headless browser fallback for when the Chrome extension isn't the right fit |
| Plugin channel | `telegram` | Inbound messaging + outbound replies so Lilo can reach the operator on their phone — required for the outbox relay loop to be useful |
| Extension | `claude-in-chrome` | Paired with the `--chrome` flag above — DOM-aware browser automation |

The first two are wired up by `.mcp.json` in this repo; the other two
come from the `--channels` plugin and the `--chrome` extension. After
first launch, run `/telegram:configure` inside Lilo to paste the bot
token and set the access policy.

### First-run checklist

1. Clone this repo into `<workspace>/claude-universe/orchestrator/`.
2. Install the Chrome extension (optional but recommended).
3. Start Lilo with the launch command above.
4. On the very first prompt, tell Lilo:

   ```
   bootstrap
   ```

   Lilo reads `BOOTSTRAP.md` and walks you through the rest
   interactively: filling out `USER.md` via a few questions, suggesting
   MCPs worth adding (Supabase, Playwright), setting up the Telegram
   bot if you want phone relay, and optionally scaffolding a throwaway
   project as a smoke test.

### Operator profile (`USER.md`)

`CLAUDE.md` imports `@USER.md` at the top. That file holds everything
operator-specific — your name, Telegram `chat_id`, terseness preference,
quiet hours — and is the one place you customise when you fork this
repo. `USER.md` is gitignored; `USER.md.example` is the committed
template, and `bootstrap` populates it for you on first boot.

## How the operator drives it

Natural-language commands. Intent routing lives in the skill
descriptions under `.claude/skills/`, so you just say what you want:

- `new project <name>` — scaffold and launch the PM in tmux
- `status` — list sibling projects and active tmux sessions
- `nuke <name>` — delete a sibling project (Lilo always confirms first)
- `bootstrap` — first-run setup (USER.md, MCPs, Telegram)
- Anything else actionable — Lilo checks the `claude-universe-tools` MCP
  first and invokes a registered tool action before writing custom logic

Team projects communicate back through
`../<project>/.lilo-outbox/*.json`. Lilo sweeps them on a recurring cron
and relays to the operator per the routing rules in `CLAUDE.md`.

## Startup ritual

Every new Lilo session must:

1. Register the outbox sweep cron (`7,37 * * * *`) if not already
   scheduled. `.claude/settings.json` has a `UserPromptSubmit` hook that
   reminds Lilo to re-verify this on every prompt — treat it as a silent
   self-check.
2. Read `CLAUDE.md` for current routing and command semantics.
3. Stay silent unless there is something to report.

## Tool registry

`./tools/registry.json` is the single source of truth for MCP-exposed
tools. Adding a new entry + restarting the MCP bridge makes it callable
from Lilo automatically — no per-tool skills, no orchestrator code
changes. Each tool exposes a `<tool>.doctor` action for on-demand health
checks.

## Feedback loop

`agent-feedback.jsonl` accumulates ratings from every PM `done` report.
Lilo periodically scans it and refines
`templates/team/.claude/agent-registry/<agent>.md` when an agent
accumulates repeated `poor` or thematic `adequate` ratings. This is the
registry's self-improvement loop.

## Sharing / cloning this repo

This repo is meant to be cloned into `<anywhere>/claude-universe/orchestrator/`.
The tools framework is in-repo at `./tools/`. After cloning:

1. `.mcp.json` uses paths relative to this repo — no edits needed.
2. `.claude/settings.json` grants Lilo read/write in this repo and its
   parent directory so it can scaffold sibling projects; adjust if your
   layout differs.
3. To register your own tools, copy `tools/registry.example.json` to
   `tools/registry.json` and add entries. The MCP bridge reads
   `registry.json` at startup and exposes every registered action.

## Rules

- Never edit sibling project code — only scaffold and relay
- Always confirm before destructive actions (`nuke`)
- Keep replies short
- The only files outside this directory Lilo owns are the sibling
  projects it scaffolds (and their `.lilo-inbox/` / `.lilo-outbox/`)
