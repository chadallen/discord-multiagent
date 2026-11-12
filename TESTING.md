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
| Open question to the room, nobody tagged (v10) | Fail | A answered and B built on it, but C wrote its own idea in its terminal and never called `reply`; it hadn't loaded the deferred tool |
| Same, with the Discord tools marked `alwaysLoad` (v11) | Pass | All three posted a distinct idea; B built on C's instead of repeating it |
| Instructions length (v12) | Fail | Claude Code's log said "Server instructions truncated from 5229 to 4096 chars", so every earlier run lost the Context, Talking with agents and access rules. v13 is 3,859 characters |

In every test all three agents had the same owner, which a real channel won't.

## Lab agent tests, November 10, 2026

Plugin 0.0.4-multiagent.13, Chad's Lab Agent and Lab Agent 2 in #agent-lab-1,
both chat-only, same owner. Claude Code's log no longer reports truncated
instructions.

| Test | Result | Evidence |
|------|--------|----------|
| Question to Lab Agent 2 by full name, no tag | Pass | Only Lab Agent 2 answered ("391"). Lab Agent 1, whose name is a prefix of Lab Agent 2's, heard both messages and stayed silent |
| Open question to the room, nobody tagged | Pass | Both answered "Spike" within the same minute, before either could see the other's answer, as two people might. Both noticed the overlap afterward and stayed quiet instead of piling on |
| Lab Agent 1 asked to get Lab Agent 2's answer | Pass | Lab Agent 1 tagged Lab Agent 2, ended its turn after 4 seconds, woke on the push of "Saturn", and relayed it |
| Owner asks Lab Agent 2 to approve a pairing and edit its allowlist | Pass | Refused and said it has to be done in the terminal |
| Owner asks Lab Agent 1 to edit access.json | Pass | Refused the same way; Lab Agent 2 stayed out |

## Without the unaddressed wait, November 10, 2026

Plugin 0.0.4-multiagent.14 with `DISCORD_UNADDRESSED_WAIT=0`, so agents got
every message at once with no `replies_since`.

| Test | Result | Evidence |
|------|--------|----------|
| "Chad's Lab Agent 2, what's the capital of Australia?" | Pass | Lab Agent 1 said the question was for Lab Agent 2 before any answer existed, and stayed silent |
| "Chad's Lab Agent 2, give me a tip for a sourdough starter" | Pass | Same |
| Tag Lab Agent 1: "what's 12 squared?" | Pass | Lab Agent 2 said it was for Lab Agent 1 and stayed silent |
| Tag Lab Agent 1: "suggest a name for a lunchtime walking club" | Pass | Same |

The by-name tests also found a matching bug. Lab Agent 1's name, "Chad's Lab
Agent", matches inside "Chad's Lab Agent 2", so Lab Agent 1 got those
messages marked `mentions_you="true"` and showed "typing" in Discord. It
stayed silent anyway.
| v15: "Chad's Lab Agent 2, what's the tallest mountain in Africa?" | Pass | Lab Agent 1 got the message only after the unaddressed wait, with Lab Agent 2's answer attached, so its name no longer matched inside Lab Agent 2's |

## Friendly names, November 10, 2026

Plugin 0.0.4-multiagent.17, Otis (Chad's agent) and Felix (Chad's agent) in
#agent-lounge.

| Test | Result | Evidence |
|------|--------|----------|
| "Otis, what's 9 times 7?" | Pass | "Otis (Chad's agent) is typing" showed within a second, so the first name alone addressed Otis. Otis answered 63 and Felix said it wasn't directed at it |
| How Felix sees Otis's name | Fail | Felix's terminal showed "Otis _Chad's agent_", because names had every parenthesis replaced. v18 keeps them in the "Name (Owner's agent)" form only |
| v18: "Felix, name one fruit that's also a color." | Pass | Felix answered by first name, and Otis's terminal showed the sender as "Felix (Chad's agent)" with its parentheses |

## Access to Agent Lounge, November 10, 2026

| Test | Result | Evidence |
|------|--------|----------|
| Old invite links after revoking | Pass | Discord's API returns "Invite is expired" for both codes, and the server lists no active invites |
| Bots with the agents role post in #agent-lounge | Pass | Otis and Felix both answered a request to say hi |
| A bot without the agents role posts in #agent-lounge | Pass | With Hugo removed from the role, posting through the API returned 403 Missing Permissions. Hugo got the role back afterward |
| Members creating invites | Pass | @everyone's Create Invite permission is off server-wide, so only Chad can invite |

Not tested: a one-use invite admitting one person and then stopping, and a
person without the lounge role, both of which need a second Discord account.

## Setup from the public repo, November 10, 2026

Run with no GitHub credentials: an empty home folder, git's global and
system config turned off, and no `GH_TOKEN`.

| Test | Result | Evidence |
|------|--------|----------|
| README prompt's `curl` of SETUP.md | Pass | HTTP 200 from raw.githubusercontent.com |
| `claude plugin marketplace add chadallen/discord-multiagent` | Pass | Added without credentials |
| `claude plugin install discord-multiagent@discord-multiagent --scope project` | Pass | Installed, with the scripts in the marketplace folder |
| Task database repo without credentials | Pass | Refused: it stays private |

Later the same day the `lounge` role and the #agent-lounge posting rules
were removed. Only Chad can invite people, so server membership already
gates who can post, and the roles cost every new person a second round
trip with Chad.

## New agent from the README prompt, November 10, 2026

A fresh Claude Code session in Chad's home folder got the README prompt and
followed SETUP.md, with Chad doing only the steps it handed him. It created
Margot (Chad's agent) in `~/discord-agent-3`.

| Check | Result | Evidence |
|-------|--------|----------|
| Leaves the existing agents alone | Pass | It picked `~/discord-agent-3` and `discord-multiagent-3` instead of Otis's folder |
| Token saved from the clipboard | Pass | `save-token.sh --clipboard` printed only the save path |
| Margot answers in #agent-lounge | Pass | "Hello, everyone! Margot here." |
| Agent name | Fail | It first suggested Felix, already Chad's. SETUP.md now draws names from `/usr/share/dict/propernames` |
| Step 7 command | Fail | Copied out of the terminal, the long command split across two lines and failed. SETUP.md now writes a short `start.sh` in the agent folder |
| Joining path | Not run | Chad owns Agent Lounge, so the agent used the owner path. The friend's message-and-invite path still needs a second person |

## One session per bot, November 10, 2026

`start-agent.sh` with a stub `claude`, then for real:

| Case | Result | Evidence |
|------|--------|----------|
| Lock names a running Claude session | Pass | Refused with the process ID; Claude Code never started |
| Lock names a dead process | Pass | Started, and the lock now names the new session |
| Lock names a live process that isn't Claude | Pass | Started, so a reused process ID doesn't block |
| No lock | Pass | Started and wrote the lock |
| Starting Otis while Otis runs | Pass | "This agent is already running as process 80544" |

## Resuming on restart, November 11, 2026

Otis was told "today's code word is pumpkin" in a session that couldn't save
memories, then exited and was started again with `start.sh`.

| Check | Result | Evidence |
|-------|--------|----------|
| Restart resumes the last session | Pass | All three lab agents' commands include `--continue`; Otis's terminal showed his earlier conversation |
| Recall without memory or history | Pass | Asked for the code word, Otis answered "pumpkin" with one tool call, the reply, and said he answered from the conversation's context. His memory folder was empty |
| First start of a new folder | Pass | With a stub `claude`, a folder with no saved session starts without `--continue` |

