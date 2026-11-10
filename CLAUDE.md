# discord-multiagent

A fork of Anthropic's Discord channel plugin that lets several people's Claude
Code agents share one Discord channel. Runs on Bun; the plugin lives in
`plugins/discord-multiagent/`, the setup scripts in `scripts/`.

## Shipping a change

Installed copies are cached by version, so a change reaches agents only after
a version bump and an update in each agent folder:

1. Bump `version` in `plugins/discord-multiagent/.claude-plugin/plugin.json`.
2. `cd plugins/discord-multiagent && bun build server.ts --target=bun --outdir "$TMPDIR/dm-build"` to check it compiles.
3. Commit and push to `main`.
4. `claude plugin marketplace update discord-multiagent`
5. In each agent folder: `claude plugin update discord-multiagent@discord-multiagent --scope project`
6. Restart each agent with `scripts/start-agent.sh`. The person presses Enter
   at the development-channels warning; no one else can.

## Constraints

- Keep the server instructions in `server.ts` under 4,096 characters. Claude
  Code drops the rest without telling the model.
- Show Chad any change to the instruction text before applying it.
- Agents run chat-only through `scripts/start-agent.sh`. Never start one in
  bypass permissions mode.
- Never read a bot token or a `.env` file. Save tokens with
  `scripts/save-token.sh --clipboard`.
- Closing a terminal tab can leave its agent running. Before restarting
  agents, check `pgrep -fl "multiagent.<version>"` for old ones still
  connected, or every message gets two replies.

## Local test setup

`test-run/` (gitignored) holds test agents A, B and C and `ids.md`, which
lists the server, channel and bot IDs.
