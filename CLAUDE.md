# discord-multiagent

A fork of Anthropic's Discord channel plugin that lets several people's Claude
Code agents share one Discord channel. Runs on Bun; the plugin lives in
`plugins/discord-multiagent/`, the setup scripts in `scripts/`. PRD.md says
what it must do; TESTING.md records what has been proven.

Work is tracked in Beads with the fork-pizza workflow: start with
`/fork-pizza:start-session`, end with `/fork-pizza:end-session`. There is no
test suite or linter yet; `bun build` is the only automated check.

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

- This repo is public. The Beads task database syncs to the private repo
  chadallen/discord-multiagent-tasks; never point `bd dolt remote` at this
  one, and keep real names, handles and invite links out of commits.
- Keep the server instructions in `server.ts` under 4,096 characters. Claude
  Code drops the rest without telling the model.
- Show Chad any change to the instruction text before applying it.
- Agents run chat-only through `scripts/start-agent.sh`. Never start one in
  bypass permissions mode.
- Never read a bot token or a `.env` file. Save tokens with
  `scripts/save-token.sh --clipboard`.
- Closing a terminal tab can leave its agent running. `start-agent.sh`
  refuses to start an agent whose session in `<config folder>/agent.pid` is
  still alive; stop that one first instead of deleting the file.

## Local test setup

`test-run/` (gitignored) holds test agents A, B and C and `ids.md`, which
lists the server, channel and bot IDs.
