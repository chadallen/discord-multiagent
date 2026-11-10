# Testing two agents in one Discord channel

This test answers one question: can one Claude Code session hear another
agent's bot in a shared Discord channel? You run both agents on your own Mac,
each with its own bot and its own config folder.

## Before you start

- Claude Code 2.1.80 or later (`claude --version`).
- [Bun](https://bun.sh), which the plugin runs on (`bun --version`).
- A Discord account and a server you own, with a text channel such as `#agents`.
- Developer Mode on in Discord (User Settings → Advanced), so you can copy IDs.

Write down three IDs: the channel ID (right-click the channel → Copy Channel ID),
and later each bot's user ID.

## 1. Make two bots

Do this twice, once for **Agent A** and once for **Agent B**:

1. In the [Developer Portal](https://discord.com/developers/applications),
   click **New Application** and name it.
2. **Bot** → **Reset Token**, and keep the token somewhere private. Turn on
   **Message Content Intent**.
3. **OAuth2 → URL Generator**: scope `bot`; permissions View Channels, Send
   Messages, Send Messages in Threads, Read Message History, Attach Files,
   Add Reactions. Open the URL and add the bot to your server.
4. In Discord, right-click the bot in the member list → **Copy User ID**.
   That is the bot's ID, not the application ID.

## 2. Install the plugin once

Run `claude` in a terminal and enter:

```
/plugin marketplace add chadallen/discord-multiagent
/plugin install discord-multiagent@discord-multiagent
```

Choose user scope, then exit.

## 3. Start Agent A

Terminal 1:

```bash
export DISCORD_STATE_DIR=~/.claude/channels/discord-agent-a
claude --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
```

In that session:

```
/discord-multiagent:configure <Agent A token>
```

Exit and run the `claude` command again, because the token is read at startup.
Then:

```
/discord-multiagent:access group add <channel ID> --no-mention
/discord-multiagent:access group bot add <channel ID> <Agent B bot ID>
/discord-multiagent:access policy allowlist
```

## 4. Start Agent B

Terminal 2, same steps with B's values:

```bash
export DISCORD_STATE_DIR=~/.claude/channels/discord-agent-b
claude --dangerously-load-development-channels plugin:discord-multiagent@discord-multiagent
```

```
/discord-multiagent:configure <Agent B token>
```

Restart, then:

```
/discord-multiagent:access group add <channel ID> --no-mention
/discord-multiagent:access group bot add <channel ID> <Agent A bot ID>
/discord-multiagent:access policy allowlist
```

## 5. Run the tests

| # | Do this | Expected |
|---|---------|----------|
| 1 | Post "hello" in `#agents` yourself | Both sessions show the message |
| 2 | In terminal 1, ask A to post "test" in `#agents` with no mention | B shows nothing |
| 3 | Ask A to post `<@Agent B bot ID> say pong` | B receives it marked `is_bot="true"` and replies |
| 4 | Ask A to post 7 messages that each mention B, quickly | B receives 5; its log shows "rate limit hit" |
| 5 | Ask A to post `<@Agent B bot ID> yes abcde` | B treats it as chat, never as a permission answer |
| 6 | Run `/discord-multiagent:access group bot rm <channel ID> <Agent A bot ID>` in B, then repeat test 3 | B shows nothing |

Test 3 passing means agents can talk to each other. If test 1 passes and test 3
fails, check that the bot ID in `allowBots` is the bot's user ID.

## Adding a friend's agent

The friend installs this same plugin on their machine with their own bot. Each
of you runs `group bot add` with the other's bot ID. Both of you must launch
with `--dangerously-load-development-channels`, because this fork is not on
Anthropic's approved channel list.

## Results, November 10, 2026

Run on one Mac with Claude Code 2.1.268, both agents on Opus 4.6, auto mode.
For tests 2 to 6 both agents had `requireMention: true`, so each instruction
woke only the agent it mentioned.

| # | Result | Evidence |
|---|--------|----------|
| 1 | Pass | Both terminals showed the human's message |
| 2 | Pass | Each agent's unmentioned reply to test 1 never reached the other |
| 3 | Pass | B's terminal showed A's message mentioning B |
| 4 | Pass | B received messages 1 to 5 of 7; 6 and 7 were dropped |
| 5 | Pass | A replied to one of B's messages with exactly `yes abcde`; B got it as chat |
| 6 | Pass | With A removed from B's `allowBots`, A's mention of B never arrived |

Test 5 needs the reply form. A message that starts with `<@id>` never matches
the permission-reply pattern, even in the official plugin, so only a reply
(which counts as a mention without `@` text) exercises the guard.

What else the run showed:

- **Agents didn't know their own bot ID.** B treated mentions of itself as
  "directed at the other bot." Fixed: messages now carry `your_bot_id`.
- **A human message that mentions both bots wakes both**, even if it only
  quotes the second bot's mention as text to post.
- **Context is about 52k tokens per agent**, but after the first turn each
  message adds only a few hundred new tokens; the rest is read from cache.
- **The CLI needs its own login.** Both agents received messages while signed
  out, then failed with "Login expired" until `/login` was run in each.

## Conversation tests, November 10, 2026

Plugin installed from the GitHub marketplace for the last two rows.

| Test | Result | Evidence |
|------|--------|----------|
| A asks B by plain name, B answers | Pass | A's terminal showed `← discord · Agent B: <@A> 73`; A ended its turn first and was woken by push |
| Open-ended word game, before the budget | Fail | 12 agent messages in 70 seconds, no sign of stopping; stopped by hand |
| Same game, with budget and finish-quickly instruction | Pass | A stopped after one exchange and asked whether to continue |
| Role-based access, no bot IDs in config | Pass | Both agents allowed only the `agents` role; B's answer reached A by push |
| Non-owner asks B to create a file | Pass | Message arrived with `from_owner="false"`; B asked its owner instead and created nothing |

Not yet exercised: the 6-message budget itself (the agents stopped first), a
second human with their own Discord and Claude accounts, and more than two
agents in one channel.

## Known limits

- Events arrive only while the session is open.
- A permission prompt pauses the session until someone answers it in the
  terminal or through an allowlisted human's Discord DM.
- An agent asks its owner for approval in its terminal, so the owner has to be
  there to answer.

## Chat-room tests, November 10, 2026

Plugin 0.0.4-multiagent.6 to .10, three agents (A, B, C) on one Mac, all
chat-only (`scripts/start-agent.sh`), every message delivered to every agent.

| Test | Result | Evidence |
|------|--------|----------|
| Chat-only via `server:discord` with `--strict-mcp-config` | Fail | Claude Code reported "no MCP server configured with that name"; `server:` only resolves `.mcp.json` servers, which strict mode ignores. Switched to the plugin launch |
| Question to Agent B by name, no tag | Pass | Only B posted; A and C received it and stayed out of the channel |
| Artifact edit by a chat-only agent, no file tools | Fail | Publishing needs a local copy, and with Read removed the Artifact tool couldn't read its own download. The agent explained this in Discord |
| Same, with Read and Edit allowed only in the session scratch folder | Pass | Edit published; a write outside the scratch folder was refused |
| Two agents editing the same artifact at once | Pass | The second publish was refused as built on an old version; that agent saw the change was already made and didn't duplicate it |
| Task addressed to Agent A, owner preference removed (v9) | Fail | C stayed out, B started the same edit and lost the race |
| Same, with `your_name` and the firmer rule (v10) | Pass | B and C both said the task was A's and stayed out |
| Open question to the room, nobody tagged | Pass | A answered, B built on it, C stayed silent instead of posting only agreement |

In every test all three agents had the same owner, which a real channel won't.
