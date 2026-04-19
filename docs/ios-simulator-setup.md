# iOS Simulator — one-time host setup

Lilo and team-template PMs can drive the Xcode iOS Simulator via the `ios-simulator` MCP server
(`ios-simulator-mcp` on npm, from joshuayoes/ios-simulator-mcp). The server is wired into:

- `orchestrator/.mcp.json` — so Lilo can build/screenshot app projects himself
- `templates/team/.mcp.json` — so every new team-mode project inherits it

The server itself is fetched via `npx` on demand; no install needed for the server. But it needs
two host-level dependencies:

## 1. Xcode + simulators

```
xcode-select --install
# then open Xcode once and install at least one iOS Simulator runtime
```

## 2. Facebook IDB (required for tap/swipe/type/UI-tree)

```
brew tap facebook/fb
brew install idb-companion pipx
pipx install --python /opt/homebrew/opt/python@3.11/bin/python3.11 fb-idb
```

**Python version gotcha:** `fb-idb` 1.1.7 is pinned to older asyncio semantics and crashes on
Python 3.13+ (`RuntimeError: There is no current event loop`). Install it under Python 3.11
(`brew install python@3.11`) explicitly, as shown above. Upgrade the pin only if upstream cuts a
new release.

Without IDB the MCP still loads, but only screenshot/install/launch work — no UI interaction or
accessibility-tree inspection.

## Verify

With a simulator booted (`open -a Simulator`), run:

```
xcrun simctl list devices booted
idb list-targets
```

Both should show the booted simulator.

## Tool surface

Once the MCP is loaded, Claude has: `get_booted_sim_id`, `open_simulator`, `install_app`,
`launch_app`, `ui_describe_all`, `ui_describe_point`, `ui_tap`, `ui_type`, `ui_swipe`,
`screenshot`, `record_video`, `stop_recording`, `ui_view`.

## Concurrency note

The simulator is a shared resource. If multiple PMs drive it at once, they'll stomp each other.
For now, one iOS project in flight at a time. Later fix: boot a named per-project simulator via
`xcrun simctl create`.

## Fallback

If IDB breaks on a future macOS/Xcode combo, the raw `xcrun simctl` CLI still covers build +
install + launch + screenshot + recordVideo via the Bash tool.
