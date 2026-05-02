# Overlays

Profile overlays for `new-project`. Applied **after** `templates/team/` is copied into a new project, so they overwrite a small set of base files.

## How it works

`new-project [--profile mvp|work] <name>`:
1. Copies `templates/team/.` into `../<name>/` (always — same skeleton for everyone).
2. If `--profile` is set and an overlay exists at `templates/overlays/<profile>/project/`, copies that subtree **on top** (overwriting). Files not present in the overlay are left untouched.
3. Reads `templates/overlays/<profile>/launch.flags` for the `claude` CLI flags used in the tmux launch.

`mvp` is the default. It has no `project/` subtree because the base team template IS the mvp config — only `launch.flags` is needed to capture the default CLI flags in one place.

## Layout

```
templates/overlays/
  README.md
  mvp/
    launch.flags          <- claude CLI flags for the mvp launch
  work/
    launch.flags          <- claude CLI flags for the work launch
    project/              <- everything in here is copied INTO the project
      .claude/settings.json
      .mcp.json
```

`launch.flags` lives at the overlay root and is never copied into the project — it is metadata read by `team-ops` to assemble the tmux launch command.

## Profiles

- **`mvp`** — loose defaults for personal/experimental projects: `--dangerously-skip-permissions`, all account connectors blocked via `--strict-mcp-config`, Bash/MCP allowlist permissive.
- **`work`** — tighter defaults for paid client work: `--permission-mode auto` (Claude self-vets each tool call, auto-approving safe ones and blocking risky ones), `--strict-mcp-config` dropped so work connectors (HubSpot/GitHub/ClickUp/Figma) load, but personal connectors (Telegram/Notion/Gmail/etc.) explicitly denied via `permissions.deny`.

## Adding a new profile

1. `mkdir templates/overlays/<profile>/` and add only the files that differ from the base.
2. Most overlays will want `.claude/settings.json` (tighter allowlist + deny rules) and `launch.flags` (CLI flags).
3. Update `new-project` SKILL.md to mention the new profile in its `--profile` arg list.

Don't fork the whole `team/` tree — that's the failure mode this overlay system exists to avoid.
