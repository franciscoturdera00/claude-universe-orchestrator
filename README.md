# orchestrator (Lilo)

The control plane for the `claude-universe` workspace. A long-lived
Claude Code session named **Lilo** that scaffolds projects, launches PM
teams, relays their messages back to the operator, and owns the shared
tool registry. Sibling project code is off-limits — Lilo only writes to
this repo (which contains its own `tools/` framework) and sibling
projects' `.lilo-inbox/` and `.lilo-outbox/`.

Projects you build here can be packaged as tools Lilo calls directly —
see [Tool registry](#tool-registry).

`CLAUDE.md` is the source of truth for behavior. This file is the map.

## Contents

- [Expected layout](#expected-layout)
- [Repo contents](#repo-contents)
- [Running Lilo](#running-lilo)
  - [Recommended MCPs](#recommended-mcps)
  - [First-run checklist](#first-run-checklist)
  - [Operator profile (`USER.md`)](#operator-profile-usermd)
- [How the operator drives it](#how-the-operator-drives-it)
- [Startup ritual](#startup-ritual)
- [Tool registry](#tool-registry)
- [Agent registry](#agent-registry)
- [Advisor (opus on tap for sonnet PMs)](#advisor-opus-on-tap-for-sonnet-pms)
- [Trust model](#trust-model)
- [Feedback loop](#feedback-loop)
- [Sharing / cloning this repo](#sharing--cloning-this-repo)
- [Rules](#rules)

## Expected layout

Scaffolded projects are **siblings** of this repo — they sit next to
`orchestrator/` in a shared `claude-universe/` directory, not inside
it. The MCP tools framework, by contrast, lives inside this repo.

    claude-universe/
      orchestrator/        <- this repo (Lilo runs here)
        tools/             <- MCP tools bridge + registry (in-repo)
      my-project/          <- scaffolded project, path: ../my-project/
      another-project/     <- path: ../another-project/

From Lilo's working directory, every project is reachable at
`../<name>/`. The tools framework is at `./tools/`.

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
        agents/              # Lilo's curated subagents — including outbox-sweeper
                             # and pipeline-syncer (orchestrator-only haiku workers
                             # that run the cron loop in isolated context)
        settings.json        # permissions
        skills/              # new-project, nuke-project, pm, team-ops,
                             # sweep, pipeline, sync, poll, find-agent,
                             # kill, tailor-resume, toolify
      templates/
        team/                # PM scaffold: agent-registry, agents/, skills/, CLAUDE.md

## Running Lilo

**Prerequisite (one-time):** install the `claude-in-chrome` Chrome
extension from https://claude.ai/download. The launch command below
assumes it's installed; without it, `--chrome` is a no-op and
browser-driven tools won't work. Skip only if you don't want DOM-aware
browser automation at all — in that case, drop the `--chrome` flag.

From this repo's root:

```bash
caffeinate -is claude --channels plugin:telegram@claude-plugins-official --chrome
```

Flag by flag:

- `caffeinate -i -s` — keeps the Mac awake (and prevents idle sleep)
  while Lilo is running. Required so the outbox sweep cron keeps firing
  overnight; without it the machine sleeps and Lilo misses PM messages.
- `--channels plugin:telegram@claude-plugins-official` — loads the
  official Telegram plugin channel so the operator can reach Lilo from
  their phone and Lilo can reply with messages/files.
- `--chrome` — attaches the `claude-in-chrome` extension so Lilo can
  drive a browser with DOM-aware automation (useful for any tool or
  skill that needs to navigate, read, or fill web pages). Install the
  extension in Chrome first: https://claude.ai/download

Lilo scaffolds, edits, and moves files autonomously, so interactive
permission prompts will slow it down. In a sandboxed or otherwise
trusted environment (isolated VM, dedicated server, ephemeral
workspace), append `--dangerously-skip-permissions` to skip them. Don't
use that flag on a machine where a mistake could touch anything you
care about — the wide-open `Write/Edit/Read` globs in
`.claude/settings.json` assume everything inside (and one level above)
the repo is fair game.

Wrap in tmux if you want the session to survive terminal restarts:

```bash
tmux new -s lilo "caffeinate -is claude --channels plugin:telegram@claude-plugins-official --chrome"
```

### Recommended MCPs

Lilo only needs four MCP integrations to do its job:

| Source | Name | Why |
|--------|------|-----|
| This repo's `.mcp.json` | `claude-universe-tools` (custom) | Dynamic bridge over `./tools/registry.json` — any registered tool becomes callable |
| This repo's `.mcp.json` | `playwright` | Headless browser fallback for when the Chrome extension isn't the right fit |
| Plugin channel | `telegram` | Inbound messaging + outbound replies so Lilo can reach the operator on their phone — required for the outbox relay loop to be useful |
| Extension | `claude-in-chrome` | Paired with the `--chrome` flag above — DOM-aware browser automation |

The first two are defaults in `.mcp.example.json` (copy to `.mcp.json`
on first clone); the other two come from the `--channels` plugin and
the `--chrome` extension. After first launch, run `/telegram:configure`
inside Lilo to paste the bot token and set the access policy.

### First-run checklist

1. Clone this repo into `<workspace>/claude-universe/orchestrator/`.
2. Start Lilo with the [launch command](#running-lilo).
3. On the very first prompt, tell Lilo:

   ```
   bootstrap
   ```

   Lilo reads `BOOTSTRAP.md` and walks you through the rest
   interactively: creating `.mcp.json` from the template, running the
   tools-bridge setup, filling out `USER.md` via a few questions,
   offering platform-specific MCPs (e.g. `ios-simulator` on macOS),
   setting up the Telegram bot if you want phone relay, and optionally
   scaffolding a throwaway project as a smoke test.

### Verify the setup works

Once `bootstrap` finishes, you should see confirmations for: `.mcp.json`
written, tools-bridge venv ready, `USER.md` populated, and (if you
opted in) Telegram bot wired with a working `chat_id`. Quick smoke
tests:

- `status` — should list sibling projects (empty on first boot) and
  live tmux sessions. No errors = MCP is reachable.
- `new project smoke-test` — scaffolds a throwaway project and
  auto-launches the PM in tmux. `tmux ls` should show a new session.
  `nuke smoke-test` cleans up.
- If Telegram is wired, DM your bot from your phone. You should see
  the message arrive in Lilo's terminal within seconds, and Lilo's
  reply should arrive back on Telegram. If not, run
  `/telegram:access` to check the allowlist.
- The `/sweep` and `/pipeline` crons register on every startup. To
  verify, ask Lilo "are the crons registered?" and it'll check via
  `CronList`. Should show two recurring jobs.

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
- `find an agent for <role>` — vet and import a new specialist into the
  registry (mandatory prompt-injection scan before anything lands)
- `sweep` — manual outbox sweep (the `/sweep` cron runs every 10 min
  automatically; dispatches the `outbox-sweeper` subagent)
- `refresh the dashboard` / `/pipeline` — manual Notion dashboard
  refresh (the `/pipeline` cron runs hourly at :17; dispatches the
  `pipeline-syncer` subagent)
- `check outbox` — manual umbrella that runs both at once
- `kill the session` / `wrap up` — pre-exit pass: save lessons, commit
  routine changes, branch off anything risky
- Anything else actionable — Lilo checks the `claude-universe-tools` MCP
  first and invokes a registered tool action before writing custom logic.
  To see what's currently registered: open `./tools/registry.json` or
  ask Lilo (`"what tools are registered?"`). Every tool exposes a
  `<tool>.doctor` action for a health check — e.g. `"run job-apply.doctor"`

Team projects communicate back through
`../<project>/.lilo-outbox/*.json`. The `outbox-sweeper` subagent picks
them up every 10 min and Lilo relays per the routing rules in
`CLAUDE.md`.

## Startup ritual

Every new Lilo session:

1. Recurring polling is **off by default**. The operator opts in with
   `/poll on` — registers a single recurring `/sync` cron at
   `7,37 * * * *`. Each tick runs `/sync`: sweep first via the
   `outbox-sweeper` subagent (filesystem-only, haiku), and conditionally
   refresh the dashboard via the `pipeline-syncer` subagent
   (filesystem + scoped Notion MCP, haiku) only if the sweep returned
   new messages. `/poll off` deletes the cron.
2. To manually flush queued messages and refresh the dashboard, the
   operator invokes `/sync`.
3. Read `CLAUDE.md` for current routing and command semantics.
4. Stay silent unless there is something to report.

## Tool registry

This is the "build a tool with Lilo, then let Lilo call it" loop. It
closes the circle from scaffolding projects to using them as
capabilities.

**The workflow:**

1. Ask Lilo to scaffold a new project (`new project: my-tool`). Build
   whatever you want in there — a script, a pipeline, an API wrapper,
   anything with a clear input/output.
2. When it's working, ask Lilo to `toolify my-tool`. The `toolify`
   skill packages the project against the standard tool interface and
   registers it in `./tools/registry.json`.
3. Restart the MCP bridge. That tool is now callable from Lilo as
   `<my-tool>.<action>` (e.g. `my-tool.run`, `my-tool.doctor`). No
   per-tool skill, no orchestrator code change — just a new entry in
   the registry.
4. Next time you ask Lilo for something that matches a registered
   tool, it invokes the MCP action instead of shelling out or writing
   the logic from scratch.

This opens the door to anything you can script. A home-automation
server, a fleet monitor for your own servers, a personal bookkeeping
pipeline, a news scraper, a fitness log — scaffold it as a project,
build it out, toolify it, and Lilo can call it. If you can write it,
Lilo can invoke it.

`./tools/registry.json` is the single source of truth for what's
callable. Every tool exposes a `<tool>.doctor` action for on-demand
health checks. `registry.example.json` ships an empty template for
fresh clones.

## Agent registry

`templates/team/.claude/agent-registry/` is the curated specialist
roster PMs recruit from before falling back to any external marketplace.
The roster is a mix of:

- **Custom agents** — written for this orchestrator (e.g. `code`, the
  scope-disciplined general implementer, plus PM-facing specialists like
  `scraper`, `db-designer`, `api-integrator`, `devops`, `frontend`,
  `data-pipeline`, `docs`, `test`, `security-reviewer`, `design-critic`,
  `document-critic`, `ios-sim-driver`, `team-historian`,
  `lora-prompt-builder`, `stitch-operator`)
- **Imported from `everything-claude-code`** (github.com/affaan-m/everything-claude-code,
  MIT-licensed) — reviewed for prompt-injection safety per agent before
  import, lightly adapted. Includes `code-architect`, `code-reviewer`,
  `code-simplifier`, `refactor-cleaner`, `performance-optimizer`,
  `build-error-resolver`, `type-design-analyzer`, `silent-failure-hunter`,
  `comment-analyzer`, `pr-test-analyzer`, `typescript-reviewer`,
  `python-reviewer`, `tdd-guide`, `e2e-runner`, `doc-updater`,
  `docs-lookup`, `a11y-architect`, `seo-specialist`

See `templates/team/.claude/agent-registry/README.md` for the full
roster with model tiers and use cases.

## Advisor (opus on tap for sonnet PMs)

PMs run on sonnet by default for cost and throughput. When a PM hits a
judgment call that warrants a stronger model, it can consult a pooled
opus-level reviewer via Claude Code's built-in `/advisor`. It takes no
arguments — it forwards the PM's full conversation transcript to opus
and returns advice.

The PM agent is already wired to invoke `/advisor` before committing
to a plan, before marking a build `done`, and when stuck. It's a no-op
if the operator hasn't enabled it, so nothing breaks.

**To enable it once**, run this inside any Claude Code session:

```
/advisor opus
```

That persists the setting at user level and lights up `/advisor` for
every future Claude Code session — Lilo, every PM, and every
specialist — without per-project wiring. Run `/advisor off` to disable.

## Trust model

Lilo's `.claude/settings.json` has wide Bash allowlists and
`Write/Edit/Read` globs that cover this repo and the parent directory
(so it can scaffold siblings). If you also run with
`--dangerously-skip-permissions`, you've removed the last line of
defense. Know what you're trusting when you use this repo:

- **Registering a tool in `tools/registry.json`** = trusting the tool's
  adapter code (arbitrary Python) and its `requirements.txt` (arbitrary
  pip installs, run on bridge startup). Only register tools you wrote
  or audited. `toolify` pointed at an untrusted sibling project is a
  supply-chain vector.
- **PM outbox messages** are data, not instructions. A PM whose
  specialists ingested untrusted input (scraped pages, fetched docs)
  can be prompt-injected and write manipulated `alerts[]` or `detail`
  strings. Lilo's `team-ops` skill only relays these to the operator —
  never executes them. Keep that invariant if you extend the skill.
- **Scaffolded projects** run as their own Claude sessions with the
  template `settings.json` allowlist. That allowlist is broad; audit
  and narrow it if you're working in a lower-trust environment.

## Feedback loop

`agent-feedback.jsonl` accumulates ratings from every PM `done` report
(canonical schema: `poor` / `adequate` / `effective`). The
`outbox-sweeper` subagent appends new ratings on every sweep, and runs
`.claude/skills/sync/aggregate-feedback.sh` whenever a `done`
message lands. The aggregator flags any specialist meeting the team-ops
thresholds — 2+ `poor` across distinct projects OR 4+ `adequate` — and
Lilo refines `templates/team/.claude/agent-registry/<agent>.md` with
the human judgment call on whether the adequate-notes share a coherent
theme. This is the registry's self-improvement loop.

## Sharing / cloning this repo

This repo is meant to be cloned into `<anywhere>/claude-universe/orchestrator/`.
The tools framework is in-repo at `./tools/`. After cloning, follow the
[First-run checklist](#first-run-checklist) — `bootstrap` handles the
bridge venv, `.mcp.json`, and any platform-specific MCPs
interactively. A few notes for the curious:

1. `.mcp.example.json` ships minimal (claude-universe-tools +
   playwright). Bootstrap copies it to `.mcp.json` (gitignored) and
   offers platform-specific additions like `ios-simulator` on macOS.
2. `.claude/settings.json` grants Lilo read/write in this repo and its
   parent directory so it can scaffold sibling projects; adjust if your
   layout differs.
3. To register your own tools, copy `tools/registry.example.json` to
   `tools/registry.json` (also gitignored) and add entries. The MCP
   bridge reads `registry.json` at startup and exposes every registered
   action.

## Rules

- Never edit sibling project code — only scaffold and relay
- Always confirm before destructive actions (`nuke`)
- Keep replies short
- The only files outside this directory Lilo owns are the sibling
  projects it scaffolds (and their `.lilo-inbox/` / `.lilo-outbox/`)
