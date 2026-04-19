# Bootstrap

Lilo: follow this script the first time you are launched in a fresh clone of this repo. The operator will trigger it by saying `bootstrap` (or anything equivalent) on the first prompt. Run through the steps in order, one question at a time — do not dump all the questions at once. Keep it conversational.

Skip steps that are already done (e.g. if `USER.md` exists and looks filled in, just confirm it with the operator and move on).

---

## Step 0 — Local config files

Two files are gitignored templates the operator needs locally. Check and create if missing:

1. `.mcp.json` — copy from `.mcp.example.json`:
   ```bash
   [ -f .mcp.json ] || cp .mcp.example.json .mcp.json
   ```
   Ask the operator if they want to add platform-specific MCPs (e.g. `ios-simulator` on macOS) and paste the snippet into their `.mcp.json` if yes.

2. `tools/registry.json` — the bridge will boot with zero tools if this is missing (fine for a fresh clone). If the operator wants starter scaffolding, copy the example:
   ```bash
   [ -f tools/registry.json ] || cp tools/registry.example.json tools/registry.json
   ```

3. Tools-bridge venv — run the setup script if `tools/mcp-bridge/.venv/` doesn't exist:
   ```bash
   [ -d tools/mcp-bridge/.venv ] || ./tools/mcp-bridge/setup.sh
   ```

---

## Step 1 — Operator profile (`USER.md`)

1. If `USER.md` does not exist, copy it from the template:
   ```bash
   cp USER.md.example USER.md
   ```
2. Ask the operator these questions, one at a time, and fill the answers into `USER.md` as you go. Keep pace — do not demand all answers before writing anything.

   - **Name** — "What should I call you?"
   - **Telegram** — "Do you want me to be able to reach you proactively on Telegram when things need your attention? (If yes, we'll wire up the bot in Step 3 and I'll ask for your `chat_id` then.)"
   - **Terseness** — "Are you usually on your phone (prefer short replies) or at a terminal (verbose is fine)?"
   - **Primary channel** — "How do you expect to reach me most of the time — Telegram, terminal, or a mix?"
   - **Anything else** — "Anything else I should know about how you work? Quiet hours, things to always or never do, projects you own?"

3. Show the operator the final `USER.md` and confirm it reads right before moving on.

---

## Step 2 — MCP suggestions

Check what MCP servers are already wired (`claude mcp list`, and read `.mcp.json`). Suggest the two below if they're missing. Do **not** install without explicit permission.

### Supabase

Useful for projects that need a hosted Postgres, auth, storage, or edge functions without standing up infra. If the operator works on web apps or anything with a backend, suggest it.

Install pointer: the Supabase MCP is an account-level integration — the operator adds it through the Claude account settings, not in this repo. Point them to the install flow and offer to continue once they confirm it's connected.

### Playwright

Already wired into this repo's `.mcp.json`. Mention that it's available for headless browser automation when the Chrome extension isn't the right fit — the operator does not need to do anything.

Also mention the `claude-in-chrome` extension (DOM-aware browser automation) and the custom `claude-universe-tools` bridge — both are covered elsewhere but worth a one-line callout so the operator knows what's on deck.

---

## Step 3 — Telegram (optional)

Only run this step if the operator said yes in Step 1. Otherwise skip.

1. **Plugin channel.** The launch command in `README.md` already includes `--channels plugin:telegram@claude-plugins-official`. Confirm the operator is using that launch line — if not, suggest they restart with it.
2. **Create a bot.** Tell the operator to open Telegram, DM `@BotFather`, run `/newbot`, and follow the prompts. BotFather returns an HTTP API token. Have them copy it.
3. **Configure the bot.** Run `/telegram:configure` inside this session, paste the token when prompted, and set the access policy.
4. **Find the `chat_id`.** Ask the operator to send a message to their new bot from Telegram. When the inbound message arrives in this session, the `chat_id` will be in the `<channel>` tag. Write that value back into `USER.md` under "Telegram chat_id" so you can proactively DM them.

---

## Step 4 — Tools framework

The `tools/` framework ships inside this repo (`./tools/`). The MCP bridge reads `tools/registry.json` at startup and exposes every registered action. On a fresh clone the registry is empty (`tools/registry.example.json` is the template).

- If the operator wants to register a custom tool, they can copy the example to `registry.json` and add entries, or use the `toolify` skill against an existing sibling project to scaffold everything automatically.
- No sibling repo needed — everything the bridge needs lives in-repo.

---

## Step 5 — Smoke test

Suggest running `new project: hello` to scaffold a throwaway project and verify the pipeline works end-to-end. Offer to nuke it afterwards.

---

## Step 6 — Wrap up

- Recap what was set up, what was skipped, and any next steps the operator still owes (e.g. install Supabase MCP in account settings).
- Remind them that `USER.md` is gitignored — safe to commit the repo without leaking their profile.
- Stop. Wait for the operator's next instruction.
